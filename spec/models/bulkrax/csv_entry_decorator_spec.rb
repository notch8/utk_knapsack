# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::CsvEntryDecorator do
  let(:csv) { Tempfile.new(['import', '.csv']) }

  after { csv.close! }

  let(:parser_fields) { { 'visibility' => 'open' } }

  def importer_for(raw_metadata)
    CSV.open(csv.path, 'w') do |rows|
      rows << raw_metadata.keys
      rows << raw_metadata.values
    end
    Bulkrax::Importer.create!(name: 'probe', admin_set_id: 'admin-set', parser_klass: 'Bulkrax::CsvParser',
                              user: ::User.system_user, field_mapping: Bulkrax.field_mappings['Bulkrax::CsvParser'],
                              parser_fields: parser_fields.merge('import_file_path' => csv.path))
                     .tap { |importer| Bulkrax::ImporterRun.create!(importer:) }
  end

  def entry_for(klass, raw_metadata)
    klass.create!(identifier: raw_metadata['source_identifier'] || 'probe:row',
                  importerexporter: importer_for(raw_metadata), raw_metadata:)
  end

  def save(resource)
    Hyrax.persister.save(resource:)
  end

  describe 'a file set row' do
    let(:file_set) do
      save(Hyrax::FileSet.new(title: ['Page 1'], bulkrax_identifier: 'probe:fs', alternate_ids: ['probe:fs'],
                              visibility: 'restricted', primary_identifier: ['probe:fs'],
                              rdf_type: ['http://pcdm.org/use#OriginalFile']))
    end

    it 'updates an existing file set from id, model and one column' do
      entry = entry_for(Bulkrax::CsvFileSetEntry, 'id' => file_set.id.to_s, 'model' => 'Hyrax::FileSet',
                                                  'title' => 'New title')

      expect { entry.build_metadata }.not_to raise_error
      expect(entry.parsed_metadata).to include('title' => ['New title'])
      expect(entry.parsed_metadata).not_to include('visibility')
    end

    it 'finds an existing file set by source identifier' do
      file_set
      entry = entry_for(Bulkrax::CsvFileSetEntry, 'source_identifier' => 'probe:fs', 'model' => 'Hyrax::FileSet',
                                                  'title' => 'New title')

      expect { entry.build_metadata }.not_to raise_error
    end

    it 'still checks a file the row does give' do
      entry = entry_for(Bulkrax::CsvFileSetEntry, 'id' => file_set.id.to_s, 'model' => 'Hyrax::FileSet',
                                                  'file' => 'missing.jpg')

      expect { entry.build_metadata }.to raise_error(Bulkrax::FileSetEntryBehavior::FilePathError)
    end

    it 'still requires a file for a new file set' do
      entry = entry_for(Bulkrax::CsvFileSetEntry, 'source_identifier' => 'probe:new', 'model' => 'Hyrax::FileSet',
                                                  'title' => 'Page 1', 'parents' => 'probe:work')

      expect { entry.build_metadata }.to raise_error(Bulkrax::FileSetEntryBehavior::FileNameError)
    end

    it 'saves only the given column' do
      intermediate = 'http://pcdm.org/use#IntermediateFile'
      create(:uri_cache, uri: intermediate, value: 'Intermediate File')
      entry = entry_for(Bulkrax::CsvFileSetEntry, 'id' => file_set.id.to_s, 'source_identifier' => 'probe-1-1',
                                                  'model' => 'Hyrax::FileSet', 'rdf_type' => intermediate)

      entry.build
      reloaded = Hyrax.query_service.find_by(id: file_set.id)

      expect(entry.status_message).to eq 'Complete'
      expect(reloaded.rdf_type).to eq [intermediate]
      expect(reloaded.title).to eq ['Page 1']
      expect(reloaded.bulkrax_identifier).to eq 'probe:fs'
      expect(reloaded.alternate_ids.map(&:to_s)).to eq ['probe:fs']
      expect(reloaded.visibility).to eq 'restricted'
    end
  end

  describe 'a work row' do
    let(:admin_set_id) do
      Hyrax::Group.find_or_create_by!(name: ::Ability.admin_group_name)
      Hyrax::AdminSetCreateService.find_or_create_default_admin_set.id
    end
    let(:work) do
      save(StillImage.new(title: ['A work'], visibility: 'restricted', admin_set_id:,
                          bulkrax_identifier: 'probe:work', alternate_ids: ['probe:work'],
                          provider: ['http://id.loc.gov/authorities/names/n2017180154'],
                          rights_statement: ['http://rightsstatements.org/vocab/InC/1.0/'],
                          primary_identifier: ['probe:work'], has_work_type: ['StillImage']))
    end

    it 'saves only the given column' do
      allow(Site.instance).to receive(:available_works).and_return(['StillImage'])
      create(:uri_cache)
      create(:uri_cache, uri: 'http://rightsstatements.org/vocab/InC/1.0/', value: 'In Copyright')
      entry = entry_for(Bulkrax::CsvEntry, 'id' => work.id.to_s, 'source_identifier' => 'probe-1-1', 'model' => 'StillImage',
                                           'abstract' => 'New abstract')

      entry.build
      reloaded = Hyrax.query_service.find_by(id: work.id)

      expect(entry.status_message).to eq 'Complete'
      expect(reloaded.abstract).to eq ['New abstract']
      expect(reloaded.title).to eq ['A work']
      expect(reloaded.bulkrax_identifier).to eq 'probe:work'
      expect(reloaded.alternate_ids.map(&:to_s)).to eq ['probe:work']
      expect(reloaded.admin_set_id).to eq admin_set_id
      expect(reloaded.visibility).to eq 'restricted'
    end

    it 'updates an existing work without title, visibility or admin set' do
      entry = entry_for(Bulkrax::CsvEntry, 'id' => work.id.to_s, 'model' => 'StillImage', 'abstract' => 'New abstract')

      expect { entry.build_metadata }.not_to raise_error
      expect(entry.parsed_metadata.keys).not_to include('visibility', 'admin_set_id')
    end

    it 'keeps the visibility of an existing work when the cell is blank' do
      entry = entry_for(Bulkrax::CsvEntry, 'id' => work.id.to_s, 'model' => 'StillImage', 'abstract' => 'New abstract',
                                           'visibility' => nil)

      entry.build_metadata

      expect(entry.parsed_metadata).not_to have_key('visibility')
    end

    it 'still updates the visibility the row gives' do
      entry = entry_for(Bulkrax::CsvEntry, 'id' => work.id.to_s, 'model' => 'StillImage', 'visibility' => 'open')

      entry.build_metadata

      expect(entry.parsed_metadata).to include('visibility' => 'open')
    end

    context 'when the importer sets a rights statement' do
      let(:rights) { 'http://rightsstatements.org/vocab/InC/1.0/' }
      let(:parser_fields) { { 'rights_statement' => rights } }

      it 'leaves the rights statement of an existing work alone' do
        entry = entry_for(Bulkrax::CsvEntry, 'id' => work.id.to_s, 'model' => 'StillImage', 'abstract' => 'New abstract')

        entry.build_metadata

        expect(entry.parsed_metadata).not_to include('rights_statement')
      end

      it 'still overrides it when the importer says to' do
        parser_fields['override_rights_statement'] = '1'
        entry = entry_for(Bulkrax::CsvEntry, 'id' => work.id.to_s, 'model' => 'StillImage', 'abstract' => 'New abstract')

        entry.build_metadata

        expect(entry.parsed_metadata).to include('rights_statement' => [rights])
      end
    end

    it 'still requires a title for a new work' do
      entry = entry_for(Bulkrax::CsvEntry, 'source_identifier' => 'probe:new', 'model' => 'StillImage',
                                           'abstract' => 'New abstract')

      expect { entry.build_metadata }.to raise_error(Bulkrax::CsvEntry::MissingMetadata)
    end

    it 'still fills the importer defaults for a new work' do
      entry = entry_for(Bulkrax::CsvEntry, 'source_identifier' => 'probe:new', 'model' => 'StillImage',
                                           'title' => 'A work')

      entry.build_metadata

      expect(entry.parsed_metadata).to include('visibility' => 'open', 'admin_set_id' => 'admin-set')
    end
  end

  describe 'a collection row' do
    let(:collection) { save(Hyrax.config.collection_class.new(title: ['A collection'])) }

    it 'leaves the collection type of an existing collection alone' do
      entry = entry_for(Bulkrax::CsvCollectionEntry, 'id' => collection.id.to_s, 'model' => 'Collection',
                                                     'abstract' => 'New abstract')

      entry.build_metadata

      expect(entry.parsed_metadata).not_to include('collection_type_gid')
    end
  end
end
