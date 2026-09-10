# frozen_string_literal: true

RSpec.shared_examples 'a UTK work indexer' do
  it 'includes HykuIndexing last so its to_solr tap runs after the M3 schema' do
    expect(described_class.ancestors[1]).to eq HykuIndexing
  end

  it 'indexes a date range year, so the work reaches the catalog date facet' do
    expect(described_class.ancestors).to include UtkDateRangeIndexing
  end
end
