# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::HasMatchersDecorator do
  let(:csv) { Tempfile.new(['import', '.csv']) }

  after { csv.close! }

  def entry_for(rows)
    CSV.open(csv.path, 'w') { |out| rows.each { |row| out << row } }
    importer = Bulkrax::Importer.create!(name: 'probe', admin_set_id: 'admin-set', parser_klass: 'Bulkrax::CsvParser',
                                         user: ::User.system_user,
                                         field_mapping: Bulkrax.field_mappings['Bulkrax::CsvParser'],
                                         parser_fields: { 'visibility' => 'open', 'import_file_path' => csv.path })
    Bulkrax::ImporterRun.create!(importer:)
    raw_metadata = Bulkrax::CsvEntry.data_for_entry(Bulkrax::CsvEntry.read_data(csv.path).first, nil, importer.parser)
    Bulkrax::CsvEntry.create!(identifier: 'probe:new', importerexporter: importer, raw_metadata:)
  end

  it 'gives a blank single-valued cell the importer default' do
    entry = entry_for([%w[source_identifier model title visibility], ['probe:new', 'StillImage', 'A work', nil]])

    entry.build_metadata

    expect(entry.parsed_metadata['visibility']).to eq 'open'
  end

  it 'still splits a multi-valued cell on the pipe' do
    entry = entry_for([%w[source_identifier model title keyword], ['probe:new', 'StillImage', 'A work', 'a | b']])

    entry.build_metadata

    expect(entry.parsed_metadata['keyword']).to eq %w[a b]
  end

  describe '#single_metadata' do
    let(:entry) { Bulkrax::CsvEntry.new }

    it 'returns nil for a list of blanks' do
      expect([[], [''], [nil], [' ']].map { |content| entry.single_metadata(content) }).to all(be_nil)
    end

    it 'still joins a value' do
      expect(entry.single_metadata('open')).to eq 'open'
    end
  end
end
