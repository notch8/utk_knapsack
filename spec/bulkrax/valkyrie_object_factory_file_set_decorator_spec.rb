# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::ValkyrieObjectFactoryFileSetDecorator do
  let(:user) { ::User.system_user }
  let(:fixture_path) { HykuKnapsack::Engine.root.join('spec', 'fixtures', 'pdfs', 'portrait.pdf') }
  let(:work) do
    Hyrax.persister.save(resource: StillImage.new(title: ['parent'], depositor: user.user_key, provider: ['UTK'],
                                                  rights_statement: ['In Copyright'], primary_identifier: ['parent'],
                                                  has_work_type: ['StillImage']))
  end

  def build_factory(title, visibility: nil, files: 1)
    attributes = { 'title' => [title], 'parents' => [work.id.to_s], 'file' => [fixture_path.to_s] * files, 'visibility' => visibility }.compact
    Bulkrax::ValkyrieObjectFactory.new(attributes:,
                                       source_identifier_value: title,
                                       work_identifier: 'bulkrax_identifier',
                                       work_identifier_search_field: 'bulkrax_identifier_tesim',
                                       related_parents_parsed_mapping: 'parents',
                                       replace_files: false,
                                       user:,
                                       klass: Hyrax::FileSet,
                                       importer_run_id: nil,
                                       update_files: false).tap do |factory|
      allow(factory).to receive(:find_record) { [nil, Hyrax.query_service.find_by(id: work.id)] }
    end
  end

  def create_file_set(title, upload = uploaded_file, visibility: nil)
    build_factory(title, visibility:).send(:create_file_set, uploaded_files: [upload.id])
  end

  def embargo_work(release_date: 1.month.from_now.to_date)
    work.embargo = Hyrax.persister.save(resource: Hyrax::Embargo.new(embargo_release_date: release_date,
                                                                     visibility_during_embargo: 'restricted',
                                                                     visibility_after_embargo: 'open'))
    Hyrax::EmbargoManager.apply_embargo_for(resource: work)
    work.permission_manager.acl.save
    Hyrax.persister.save(resource: work)
  end

  def reloaded(file_set)
    Hyrax.query_service.find_by(id: file_set.id)
  end

  def uploaded_file
    Hyrax::UploadedFile.create(file: File.open(fixture_path), user:)
  end

  def member_titles
    Hyrax.query_service.find_members(resource: Hyrax.query_service.find_by(id: work.id)).map { |member| member.title.first }
  end

  before do
    DatabaseCleaner.clean
    Hyrax::Group.find_or_create_by!(name: ::Ability.admin_group_name)
  end

  after do
    ids = Valkyrie::Persistence::Postgres::ORM::Resource.pluck(:id)
    Hyrax::SolrService.delete_by_query("{!terms f=id}#{ids.join(',')}") if ids.any?
    Hyrax::SolrService.commit
    DatabaseCleaner.clean_with(:deletion, except: %w[hyrax_flexible_schemas])
    DatabaseCleaner.start
  end

  it 'creates the file set and leaves the work untouched' do
    file_set = create_file_set('first')

    expect(file_set).to be_a(Hyrax::FileSet).and(be_persisted)
    expect(file_set.title).to eq ['first']
    expect(Hyrax.query_service.find_by(id: work.id).member_ids).to be_empty
  end

  it 'leaves the ingest for the relationship pass' do
    expect { create_file_set('first') }.not_to have_enqueued_job(ValkyrieIngestJob)
  end

  context 'with a visibility on the row' do
    it "gives the file set that visibility rather than the work's" do
      file_set = create_file_set('first', visibility: 'open')

      expect(Hyrax.query_service.find_by(id: work.id).visibility).to eq 'restricted'
      expect(reloaded(file_set).visibility).to eq 'open'
    end

    it "does not copy down the work's embargo" do
      embargo_work
      file_set = create_file_set('first', visibility: 'open')

      expect(reloaded(file_set).embargo).to be_nil
      expect(reloaded(file_set).visibility).to eq 'open'
    end
  end

  context 'without a visibility on the row' do
    it "inherits the work's visibility" do
      work.visibility = 'authenticated'
      work.permission_manager.acl.save

      expect(reloaded(create_file_set('first')).visibility).to eq 'authenticated'
    end

    it "inherits the work's embargo" do
      release_date = 1.month.from_now.to_date
      embargo_work(release_date:)

      file_set = reloaded(create_file_set('first'))

      expect(file_set.embargo.embargo_release_date.to_date).to eq release_date
      expect(file_set.embargo.visibility_after_embargo).to eq 'open'
      expect(file_set.visibility).to eq 'restricted'
    end

    it "inherits the work's lease" do
      work.lease = Hyrax.persister.save(resource: Hyrax::Lease.new(lease_expiration_date: 1.month.from_now.to_date,
                                                                   visibility_during_lease: 'open',
                                                                   visibility_after_lease: 'restricted'))
      Hyrax::LeaseManager.apply_lease_for(resource: work)
      work.permission_manager.acl.save
      Hyrax.persister.save(resource: work)

      file_set = reloaded(create_file_set('first'))

      expect(file_set.lease.visibility_after_lease).to eq 'restricted'
      expect(file_set.visibility).to eq 'open'
    end
  end

  it 'fails a row with more than one file without creating anything' do
    factory = build_factory('first', files: 2)

    expect { factory.send(:create_file_set, uploaded_files: [uploaded_file.id, uploaded_file.id]) }
      .to raise_error(StandardError, 'first lists 2 files; a file set row takes one')
    expect(Hyrax.query_service.find_all_of_model(model: Hyrax::FileSet).to_a).to be_empty
  end

  it 'fails the entry when there is no file to attach' do
    upload = uploaded_file
    upload.update!(file_set_uri: 'already-attached')

    expect { create_file_set('first', upload) }.to raise_error(StandardError, 'first has no file to attach')
  end

  describe 'updating a file set from a remote file' do
    let(:url) { 'https://example.com/files/two_pages.pdf' }
    let(:storage) { Valkyrie::StorageAdapter.find(:test_disk) }
    let(:versions) { false }
    let(:file_set) do
      file_set = Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ['first'], primary_identifier: ['first'],
                                                                   rdf_type: ['http://pcdm.org/use#OriginalFile']))
      File.open(copy_of('portrait.pdf')) { |io| Hyrax::ValkyrieUpload.file(io:, filename: 'portrait.pdf', file_set:) }
      reloaded(file_set)
    end

    before do
      allow(Hyrax).to receive(:storage_adapter).and_return(storage)
      allow(storage).to receive(:supports?).and_call_original
      allow(storage).to receive(:supports?).with(:versions).and_return(versions)
      stub_request(:head, %r{\Ahttps://example\.com/files/})
      stub_request(:get, %r{\Ahttp://pcdm\.org/})
    end

    def copy_of(name)
      File.join(Dir.mktmpdir, name).tap { |path| FileUtils.cp(HykuKnapsack::Engine.root.join('spec', 'fixtures', 'pdfs', name), path) }
    end

    def update_factory(remote_files: [url])
      Bulkrax::ValkyrieObjectFactory.new(attributes: { 'title' => ['first'], 'remote_files' => remote_files },
                                         source_identifier_value: 'first',
                                         work_identifier: 'bulkrax_identifier',
                                         work_identifier_search_field: 'bulkrax_identifier_tesim',
                                         user:,
                                         klass: Hyrax::FileSet,
                                         update_files: true).tap do |factory|
        allow(factory).to receive(:object).and_return(file_set)
        allow(factory).to receive(:download_file) { |remote| copy_of(File.basename(remote)) }
      end
    end

    def update_from(factory)
      factory.send(:update_file_set, factory.send(:transform_attributes, update: true))
    end

    def originals(resource)
      Hyrax.custom_queries.find_many_file_metadata_by_use(resource:, use: Hyrax::FileMetadata::Use::ORIGINAL_FILE).to_a
    end

    def add_thumbnail
      File.open(copy_of('rotated.pdf')) do |io|
        Hyrax::ValkyrieUpload.file(io:, filename: 'thumbnail.jpg', file_set:, use: Hyrax::FileMetadata::Use::THUMBNAIL_IMAGE)
      end
    end

    def write_disk_derivative
      Hyrax::DerivativePath.derivative_path_for_reference(file_set, 'txt').tap do |path|
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, 'old text')
      end
    end

    def file_ids_of(resource)
      Hyrax.custom_queries.find_files(file_set: reloaded(resource)).map(&:id)
    end

    def stored_bytes(file_metadata)
      Hyrax.storage_adapter.find_by(id: file_metadata.file_identifier).read
    end

    it 'replaces the original file with the remote one' do
      previous = file_set.original_file

      updated = update_from(update_factory)

      expect(originals(updated).map(&:original_filename)).to eq ['two_pages.pdf']
      expect(updated.file_ids).not_to include(previous.id)
      expect { Hyrax.custom_queries.find_file_metadata_by(id: previous.id) }.to raise_error(Valkyrie::Persistence::ObjectNotFoundError)
      expect { storage.find_by(id: previous.file_identifier) }.to raise_error(Valkyrie::StorageAdapter::FileNotFound)
    end

    it "detaches the old original's derivatives" do
      thumbnail = add_thumbnail

      updated = update_from(update_factory)

      expect(file_ids_of(updated)).to eq originals(updated).map(&:id)
      expect { Hyrax.custom_queries.find_file_metadata_by(id: thumbnail.id) }.to raise_error(Valkyrie::Persistence::ObjectNotFoundError)
    end

    it "removes the old file's derivatives on disk" do
      derivative = write_disk_derivative

      update_from(update_factory)

      expect(File).not_to exist(derivative)
    end

    it 'queues a reindex of the parent work for its text' do
      work.member_ids += [file_set.id]
      Hyrax.persister.save(resource: work)

      expect { update_from(update_factory) }
        .to have_enqueued_job(HykuKnapsack::ReindexWorkJob).with(work.id.to_s)
    end

    it 'indexes the file set without the old original' do
      previous = file_set.original_file

      update_from(update_factory)

      expect(Hyrax::SolrService.query("id:#{file_set.id}", fl: 'file_ids_ssim').first['file_ids_ssim']).not_to include(previous.id.to_s)
    end

    { 'MD5' => Digest::MD5, 'SHA1' => Digest::SHA1 }.each do |name, digest|
      it "keeps the original file when the remote one matches its #{name} checksum" do
        previous = file_set.original_file
        previous.checksum = [digest.file(copy_of('portrait.pdf')).hexdigest]
        Hyrax.persister.save(resource: previous)

        derivative = write_disk_derivative

        updated = update_from(update_factory(remote_files: ['https://example.com/files/portrait.pdf']))

        expect(originals(updated).map(&:id)).to eq [previous.id]
        expect(File).to exist(derivative)
      end
    end

    it 'fails a row with more than one remote file without touching the file' do
      previous = file_set.original_file
      factory = update_factory(remote_files: [url, 'https://example.com/files/other.pdf'])

      expect { update_from(factory) }.to raise_error(StandardError, 'first lists 2 files; a file set row takes one')
      expect(originals(reloaded(file_set)).map(&:id)).to eq [previous.id]
    end

    context 'with storage that keeps versions' do
      let(:versions) { true }

      it 'stores the remote file as a new version of the same original' do
        previous = file_set.original_file

        updated = update_from(update_factory)

        expect(originals(updated).map(&:id)).to eq [previous.id]
        expect(stored_bytes(originals(updated).first)).to eq File.binread(copy_of('two_pages.pdf'))
      end

      it "detaches the original's derivatives" do
        previous = file_set.original_file
        add_thumbnail

        expect(file_ids_of(update_from(update_factory))).to eq [previous.id]
      end
    end
  end

  describe 'two file sets imported at once for one work' do
    let(:titles) { %w[first second] }
    let(:importer) do
      Bulkrax::Importer.create!(name: 'probe', admin_set_id: 'admin-set', parser_klass: 'Bulkrax::CsvParser', user:,
                                field_mapping: Bulkrax.field_mappings['Bulkrax::CsvParser'])
    end

    # Holds both threads at upstream's attach step, so the examples fail if create_file_set goes back to saving the work.
    def hold_both_at_upstream_attach
      arrived = Queue.new
      allow_any_instance_of(Bulkrax::ValkyrieObjectFactory).to receive(:perform_transaction_for).and_wrap_original do |original, **kwargs, &block|
        arrived << true
        deadline = 2.seconds.from_now
        sleep 0.05 until arrived.size > 1 || Time.current > deadline
        original.call(**kwargs, &block)
      end
    end

    def create_at_once
      # Otherwise both threads race to create it inside upstream's form prepopulation.
      Hyrax::AdminSetCreateService.find_or_create_default_admin_set
      hold_both_at_upstream_attach

      titles.map { |title| [title, uploaded_file] }.map do |title, upload|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            factory = build_factory(title).tap { |f| f.attributes['bulkrax_identifier'] = [title] }
            ActiveRecord::Base.cache { factory.send(:create_file_set, uploaded_files: [upload.id]) }
          end
        end
      end.each(&:join)
    end

    it 'creates both without touching the work' do
      create_at_once

      expect(Hyrax.query_service.find_all_of_model(model: Hyrax::FileSet).map { |fs| fs.title.first }).to match_array titles
      expect(Hyrax.query_service.find_by(id: work.id).member_ids).to be_empty
    end

    it 'puts both in the work once their entries are related' do
      run = Bulkrax::ImporterRun.create!(importer:)
      create_at_once
      titles.each do |title|
        Bulkrax::CsvFileSetEntry.create!(identifier: title, importerexporter: importer,
                                         parsed_metadata: { 'parents' => [work.id.to_s] }).parent_jobs
      end

      Bulkrax::CreateRelationshipsJob.perform_now(parent_identifier: work.id.to_s, importer_run_id: run.id,
                                                  run_user: create(:superadmin))

      expect(member_titles).to match_array titles
    end
  end
end
