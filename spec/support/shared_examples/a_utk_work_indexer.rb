# frozen_string_literal: true

RSpec.shared_examples 'a UTK work indexer' do
  it 'includes HykuIndexing last so its to_solr tap runs after the M3 schema' do
    expect(described_class.ancestors[1]).to eq HykuIndexing
  end

  it 'indexes creation and publication years for the date range facet, but not other dates' do
    dated = Hyrax.persister.save(resource: resource.class.new(date_created_d: ['1911'], date_other_d: ['1850']))

    expect(described_class.new(resource: dated).to_solr[DateRangeIndexing::SOLR_FIELD]).to eq [1911]
  end

  it 'indexes URI labels for controlled vocabulary properties' do
    expect(described_class.ancestors).to include UtkUriLabelIndexing
  end
end
