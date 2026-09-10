# frozen_string_literal: true

require 'rails_helper'
require 'hyrax/specs/shared_specs/indexers'

RSpec.describe DigitalCollectionIndexer do
  let(:indexer_class) { described_class }
  let!(:resource) { Hyrax.persister.save(resource: DigitalCollection.new) }

  it_behaves_like 'a Hyrax::Resource indexer'

  it 'indexes the tenant fields supplied by HykuIndexing' do
    expect(described_class.new(resource:).to_solr)
      .to include('account_cname_tesim' => Site.instance.account&.cname)
  end
end
