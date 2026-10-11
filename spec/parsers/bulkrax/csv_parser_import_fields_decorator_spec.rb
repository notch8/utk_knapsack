# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::CsvParserImportFieldsDecorator do
  let(:csv) { Tempfile.new(['import', '.csv']) }
  let(:importer) do
    Bulkrax::Importer.create!(name: 'probe', admin_set_id: 'admin-set', parser_klass: 'Bulkrax::UtkMigrationCsvParser',
                              user: ::User.system_user,
                              field_mapping: Bulkrax.field_mappings['Bulkrax::UtkMigrationCsvParser'],
                              parser_fields: { 'import_file_path' => csv.path })
  end
  let(:sheet) do
    "source_identifier,model,title,parents,Creator (name)\n" \
      "w:1,StillImage,One,collections:a,\n" \
      "w:1_OBJ_fileset,FileSet,,w:1,Someone\n"
  end

  after { csv.close! }

  before { File.write(csv.path, sheet) }

  it 'names the same fields as merging every row' do
    expected = importer.parser.records.inject(:merge).keys.compact.uniq

    expect(importer.parser.class.new(importer).import_fields).to eq expected
  end

  it 'does not read every row' do
    parser = importer.parser.class.new(importer)

    expect(parser).not_to receive(:records)
    parser.import_fields
  end
end
