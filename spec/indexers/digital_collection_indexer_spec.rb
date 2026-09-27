# frozen_string_literal: true

require 'rails_helper'
require 'hyrax/specs/shared_specs/indexers'

RSpec.describe DigitalCollectionIndexer do
  let(:indexer_class) { described_class }
  let!(:resource) { Hyrax.persister.save(resource: DigitalCollection.new) }

  it_behaves_like 'a Hyrax::Resource indexer'

  it 'indexes a date range year, so collections reach the catalog date facet' do
    collection = Hyrax.persister.save(resource: DigitalCollection.new(title: ['Dated'], date_created_d: ['1911']))

    expect(described_class.new(resource: collection).to_solr[DateRangeIndexing::SOLR_FIELD]).to eq [1911]
  end

  it 'feeds the date range facet only creation and publication dates, as works do' do
    expect(described_class.new(resource:).send(:date_properties)).to eq %i[date_created_d date_issued_d]
  end

  it 'indexes the tenant fields supplied by HykuIndexing' do
    expect(described_class.new(resource:).to_solr)
      .to include('account_cname_tesim' => Site.instance.account&.cname)
  end

  it 'indexes URI labels for controlled vocabulary properties' do
    expect(described_class.ancestors).to include UtkUriLabelIndexing
  end

  it 'records which collection cites a controlled URI that does not resolve' do
    uri = 'http://vocab.getty.edu/aat/30004630'
    fetched = instance_double(ActiveTriples::Resource)
    allow(ActiveTriples::Resource).to receive(:new).and_return(fetched)
    allow(fetched).to receive(:fetch).and_raise(IOError, "<#{uri}>: 404")
    collection = Hyrax.persister.save(resource: DigitalCollection.new(title: ['Cites a bad form'], form: [uri]))

    described_class.new(resource: collection).to_solr

    expect(UriCitation.where(tenant: Apartment::Tenant.current).pluck(:work_id, :uri))
      .to eq [[collection.id.to_s, uri]]
  end
end
