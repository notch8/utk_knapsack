# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource StillImage`
require 'rails_helper'
require 'hyrax/specs/shared_specs/indexers'

RSpec.describe StillImageIndexer do
  let(:indexer_class) { described_class }
  let!(:resource) { Hyrax.persister.save(resource: StillImage.new) }

  it_behaves_like 'a Hyrax::Resource indexer'

  it 'includes HykuIndexing last so its to_solr tap runs after the M3 schema' do
    expect(described_class.ancestors[1]).to eq HykuIndexing
  end
end
