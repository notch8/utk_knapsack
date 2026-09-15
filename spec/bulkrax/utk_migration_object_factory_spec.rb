# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::UtkMigrationObjectFactory do
  let(:digest) { 'c19ecaa728169901792d5595f3a11e02cc16e3a0' }
  let(:work_id) { 'aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb' }
  let(:file_set_id) { 'cccccccc-4444-5555-6666-dddddddddddd' }

  # `allocate` skips the ten-argument initializer for the examples that exercise
  # a single private method and need no Bulkrax state at all.
  let(:bare_factory) { described_class.allocate }

  def build_factory(klass, attributes)
    described_class.new(attributes:,
                        source_identifier_value: attributes[:source_identifier],
                        work_identifier: 'bulkrax_identifier',
                        work_identifier_search_field: 'bulkrax_identifier_tesim',
                        related_parents_parsed_mapping: 'parents',
                        replace_files: false,
                        user: ::User.system_user,
                        klass:,
                        importer_run_id: nil,
                        update_files: false)
  end

  # DatabaseCleaner rolls back everything these examples write to Postgres.
  # Solr is the only store that survives, and a stale `probe:` document would be
  # found by the parent lookup in a later example.
  after { Hyrax::SolrService.delete_by_query('bulkrax_identifier_tesim:probe*', params: { commit: true }) }

  describe 'the sha1' do
    let(:file_set) { Hyrax::FileSet.new(id: ::Valkyrie::ID.new('fake-file-set')) }
    let(:attrs) { { sha1: digest, mime_type: 'image/tiff', original_filename: 'OBJ', file_size: ['1'] } }
    let(:metadata) { bare_factory.send(:file_metadata_for, file_set, attrs, digest) }

    it 'lands in checksum, which is what the IIIF identifier is built from' do
      expect(Array(metadata.checksum).map(&:to_s)).to eq [digest]
    end

    it 'addresses the bytes already in the repository rather than uploading' do
      expect(metadata.file_identifier.to_s).to eq "shrine://#{digest}"
    end

    it 'marks the file as the original' do
      expect(metadata.pcdm_use).to include Hyrax::FileMetadata::Use::ORIGINAL_FILE
    end

    it 'names the file after the datastream rather than the title' do
      expect(Array(metadata.original_filename)).to eq ['OBJ']
    end
  end

  describe 'the file identifier' do
    subject(:identifier) { bare_factory.send(:file_identifier_for, digest) }

    it 'addresses the object by its digest, which is the S3 key' do
      expect(identifier).to eq "shrine://#{digest}"
    end

    context 'with the disk adapter a local stack falls back to' do
      let(:base_path) { Rails.root.join('tmp', 'storage-probe') }

      before do
        allow(Hyrax).to receive(:storage_adapter)
          .and_return(Valkyrie::Storage::Disk.new(base_path:))
      end

      it 'addresses a path, because the disk adapter has no notion of a key' do
        expect(identifier).to eq "disk://#{base_path.join(digest)}"
      end
    end
  end

  describe 'creating from a row' do
    let(:admin_set) { Hyrax.persister.save(resource: AdminControl.new(title: ['Probe admin set'])) }
    let(:work_attrs) { { id: work_id, source_identifier: 'probe:1', title: ['Probe'], visibility: 'restricted' } }

    def create_work(attrs)
      build_factory(StillImage, attrs).send(:create_work, attrs)
    end

    def create_file_set(attrs)
      build_factory(Hyrax::FileSet, attrs).send(:create_file_set, attrs)
    end

    # Block form so the admin set is built only by the examples that reach for it.
    before { allow(described_class).to receive(:find_or_create_default_admin_set) { admin_set } }

    # Every production id is already a UUID, and keeping it is what holds work
    # URLs, ARKs and the IIIF cache alive across the migration.
    it 'persists a work at the id the row supplies' do
      saved = create_work(work_attrs.merge(visibility: 'open'))

      expect(Hyrax.query_service.find_by(id: saved.id).id.to_s).to eq work_id
    end

    # The stock lookup raises on a miss, so an id that does not exist here yet
    # would abort before `create` could preserve it.
    it 'reports a preserved id that is not here yet as absent rather than raising' do
      attrs = { id: 'eeeeeeee-7777-8888-9999-ffffffffffff', source_identifier: 'probe:3' }

      expect(build_factory(StillImage, attrs).send(:find_by_id)).to be false
    end

    # The whole create path: digest, parent lookup by identifier, preserved id,
    # and a visibility that differs from the parent's.
    it 'creates a file set at its own id with the row\'s own visibility' do
      work = create_work(work_attrs)
      file_set = create_file_set(id: file_set_id, source_identifier: 'probe:4', sha1: digest,
                                 mime_type: 'text/xml', original_filename: 'MODS', title: ['MODS'],
                                 parents: ['probe:1'], visibility: 'open')
      reloaded = Hyrax.query_service.find_by(id: file_set.id)

      expect(reloaded.id.to_s).to eq file_set_id
      expect(reloaded.visibility).to eq 'open'
      expect(Hyrax.query_service.find_by(id: work.id).visibility).to eq 'restricted'
    end

    # A nonblank value that is not a digest would be written straight into
    # `checksum` and used as the S3 key, so the bytes would be missing and the
    # checksum would be lying about what they are.
    it 'refuses a digest that is not a sha1' do
      expect { create_file_set(id: file_set_id, source_identifier: 'probe:7', parents: ['probe:1'], sha1: 'urn:sha1:not-stripped') }
        .to raise_error(described_class::MissingDigestError, /not a sha1/)
    end

    it 'refuses a file set row with no digest rather than creating one with no file' do
      expect { create_file_set(id: file_set_id, source_identifier: 'probe:2', parents: ['probe:1'], sha1: '') }
        .to raise_error(described_class::MissingDigestError, /probe:2/)
    end

    it 'refuses a file set row whose parent does not exist rather than orphaning it' do
      expect { create_file_set(id: file_set_id, source_identifier: 'probe:5', sha1: digest, mime_type: 'text/xml', parents: ['probe:nowhere']) }
        .to raise_error(described_class::MissingParentError, /probe:nowhere/)
    end

    # iiif_print builds `digest_ssim` from the original file's `checksum`, and it
    # reaches that file through the file set's `file_ids`. Without the link the
    # digest is intact and the image is still unresolvable.
    it 'links the file metadata so the digest is reachable from the file set' do
      file_set = Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ['Probe']))
      attrs = { sha1: digest, mime_type: 'image/tiff', original_filename: 'OBJ', file_size: ['1'] }

      linked = build_factory(Hyrax::FileSet, attrs).send(:attach_files, file_set, attrs, digest)
      original = Hyrax.custom_queries.find_file_metadata_by(id: linked.file_ids.first)

      expect(Array(original.checksum).first.to_s).to eq digest
      expect(UtkMigrationCharacterizationJob).to have_been_enqueued.with(original.id.to_s)
    end
  end

  describe 'what the stock create_work transaction would have done' do
    let(:admin_set) { Hyrax.persister.save(resource: AdminControl.new(title: ['Probe admin set'])) }
    let(:template) { Hyrax::PermissionTemplate.create!(source_id: admin_set.id.to_s) }
    let(:attrs) { { source_identifier: 'probe:workflow', title: ['Probe'], visibility: 'open' } }
    let(:work) { build_factory(StillImage, attrs).send(:create_work, attrs) }

    before do
      Hyrax::Group.find_or_create_by!(name: 'editors')
      template.access_grants.create!(agent_type: 'group', agent_id: 'editors', access: 'manage')
      workflow = Sipity::Workflow.create!(name: 'probe', active: true, permission_template: template)
      state = Sipity::WorkflowState.create!(workflow:, name: 'deposited')
      Sipity::WorkflowAction.create!(workflow:, name: 'deposit', resulting_workflow_state: state)
      allow(described_class).to receive(:find_or_create_default_admin_set) { admin_set }
    end

    # `work_resource.apply_permission_template`. Visibility alone grants only
    # `read:group/public`, so a role held on the admin set would never reach the
    # works migrated into it.
    it 'grants the admin set template\'s roles as well as the row\'s visibility' do
      grants = Hyrax::AccessControlList.new(resource: work).permissions.map { |p| "#{p.mode}:#{p.agent}" }

      expect(grants).to include('edit:group/editors', 'read:group/public')
    end

    # `work_resource.add_file_sets` copies the work's ACL onto each file set
    # (WorkUploadsHandler). A file set has no `admin_set_id`, so the template
    # lookup that covers works finds nothing and reaches them only this way.
    it 'gives a file set the grants its parent work holds' do
      fs_attrs = { source_identifier: 'probe:fs', parents: [attrs[:source_identifier]], sha1: digest,
                   mime_type: 'image/tiff', original_filename: 'OBJ', visibility: 'open' }
      fs_factory = build_factory(Hyrax::FileSet, fs_attrs)
      allow(fs_factory).to receive(:parent_work).and_return(work)
      file_set = fs_factory.send(:create_file_set, fs_attrs)
      grants = Hyrax::AccessControlList.new(resource: file_set).permissions.map { |p| "#{p.mode}:#{p.agent}" }

      expect(grants).to include('edit:group/editors', 'read:group/public')
    end

    # The stock path reaches workflow through `object.deposited`, which
    # `Hyrax.persister.save` does not publish.
    it 'puts the work in the admin set\'s workflow' do
      entity = Sipity::Entity.find_by(proxy_for_global_id: Hyrax::GlobalID(work).to_s)

      expect(entity.workflow_state.name).to eq 'deposited'
    end
  end

  describe 'derivatives already on disk' do
    let(:attrs) { { sha1: digest, mime_type: 'image/tiff', original_filename: 'OBJ' } }
    # Under the configured derivatives root, so the disk adapter can resolve it.
    let(:root) { Pathname.new(Dir.mktmpdir(nil, Hyrax.config.derivatives_path)) }
    let(:file_set) { Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ['Probe'])) }

    before { allow(Hyrax.config).to receive(:derivatives_path).and_return(root) }

    after { FileUtils.remove_entry(root) }

    # The pairtree Hyrax's derivative adapter writes to, which is why the legacy
    # files can be copied in rather than regenerated.
    def write_derivative(suffix, content)
      pairs = file_set.id.to_s.scan(/../)
      dir = root.join(*pairs[0..-2])
      FileUtils.mkdir_p(dir)
      File.write(dir.join("#{pairs[-1]}-#{suffix}"), content)
    end

    def uses_of(resource)
      resource.file_ids.flat_map do |id|
        Array(Hyrax.custom_queries.find_file_metadata_by(id:).pcdm_use)
          .map { |use| use.to_s.split(%r{[#/]}).last }
      end
    end

    it 'attaches each one so the file set can derive thumbnail_id from it' do
      write_derivative('thumbnail.jpeg', 'jpeg bytes')

      linked = bare_factory.send(:attach_files, file_set, attrs, digest)
      reloaded = Hyrax.query_service.find_by(id: linked.id)
      thumbnail = Hyrax.custom_queries.find_file_metadata_by(id: reloaded.thumbnail_id)

      expect(uses_of(reloaded)).to contain_exactly('OriginalFile', 'ThumbnailImage')
      expect(Array(thumbnail.original_filename).first).to end_with '-thumbnail.jpeg'
      expect(Array(thumbnail.mime_type).first).to eq 'image/jpeg'
      expect(thumbnail.file.read).to eq 'jpeg bytes'
      expect(thumbnail.file_set_id.to_s).to eq file_set.id.to_s
    end

    # `extracted_text` is Hyrax's own container name; `txt`, `xml` and `json` are
    # iiif_print's, and not siblings: `xml` is the ALTO, and it derives the other
    # two from it.
    it 'recognises both the Hyrax and the iiif_print names for extracted text' do
      %w[extracted_text.txt txt.txt xml.xml json.json].each { |name| write_derivative(name, "text as #{name}") }

      linked = bare_factory.send(:attach_files, file_set, attrs, digest)

      expect(uses_of(linked)).to contain_exactly('OriginalFile', *Array.new(4, 'ExtractedText'))
    end

    it 'skips a derivative that was written empty' do
      write_derivative('thumbnail.jpeg', '')

      linked = bare_factory.send(:attach_files, file_set, attrs, digest)

      expect(linked.file_ids.size).to eq 1
    end

    it 'files an unrecognised derivative as a service file rather than dropping it' do
      write_derivative('jp2.jp2', 'jp2 bytes')

      linked = bare_factory.send(:attach_files, file_set, attrs, digest)

      expect(uses_of(linked)).to include 'ServiceFile'
    end
  end
end
