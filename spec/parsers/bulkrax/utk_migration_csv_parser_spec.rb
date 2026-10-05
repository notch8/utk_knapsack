# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::UtkMigrationCsvParser do
  # A typo in any of these silently falls back to a stock entry, which uses the
  # global object factory and expects an uploaded file.
  it 'routes work rows to the migration entry' do
    expect(described_class.new(nil).entry_class).to eq Bulkrax::UtkMigrationCsvEntry
  end

  it 'routes file set rows to the migration entry' do
    expect(described_class.new(nil).file_set_entry_class).to eq Bulkrax::UtkMigrationCsvFileSetEntry
  end

  it 'is offered in the importer form' do
    expect(Bulkrax.parsers.map { |parser| parser[:class_name] }).to include described_class.to_s
  end

  describe 'reading a migration sheet' do
    let(:csv) do
      Tempfile.new(['migration', '.csv']).tap do |file|
        file.write(<<~CSV)
          source_identifier,model,parents,title,sha1,mime_type,original_filename
          probe:work,StillImage,,A work,,,
          probe:fs,FileSet,probe:work,A file set,#{'a' * 40},image/tiff,OBJ
        CSV
        file.rewind
      end
    end
    let(:importer) do
      Bulkrax::Importer.create!(name: 'probe', admin_set_id: 'admin-set',
                                parser_klass: described_class.to_s, user: ::User.system_user,
                                parser_fields: { 'import_file_path' => csv.path })
    end

    after { csv.close! }

    it 'routes each row to the entry class its model names' do
      importer.parser.create_objects(%w[work file_set])

      expect(importer.entries.map { |entry| entry.class.name })
        .to contain_exactly('Bulkrax::UtkMigrationCsvEntry', 'Bulkrax::UtkMigrationCsvFileSetEntry')
    end

    # The columns that address existing content are not model properties, so the
    # matcher drops them unless the entry claims them.
    it 'carries the file pointer columns into the file set row' do
      importer.parser.create_objects(%w[work file_set])
      entry = importer.entries.find { |e| e.identifier == 'probe:fs' }
      entry.build_metadata

      expect(entry.parsed_metadata.values_at('sha1', 'mime_type', 'original_filename'))
        .to eq ['a' * 40, 'image/tiff', 'OBJ']
    end
  end
end
