# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::CsvParserUpdateDecorator do
  let(:csv) { Tempfile.new(['import', '.csv']) }
  let(:importer) do
    Bulkrax::Importer.create!(name: 'probe', admin_set_id: 'admin-set', parser_klass: 'Bulkrax::CsvParser',
                              user: ::User.system_user, field_mapping: Bulkrax.field_mappings['Bulkrax::CsvParser'],
                              parser_fields: { 'import_file_path' => csv.path })
  end

  after { csv.close! }

  it 'accepts a sheet with no title column' do
    File.write(csv.path, "id,model,abstract\nabc,StillImage,New abstract\n")

    expect(importer.parser.valid_import?).to be true
  end

  it 'still rejects a sheet that is not valid CSV' do
    File.write(csv.path, "id,model,abstract\nabc,StillImage,\"unclosed\n")

    expect(importer.parser.valid_import?).to be false
    expect(importer.current_status.error_class).to eq 'CSV::MalformedCSVError'
  end

  it 'still rejects a sheet whose file cannot be read' do
    File.delete(csv.path)

    expect(importer.parser.valid_import?).to be false
  end
end
