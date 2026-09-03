# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource Newspaper`
require 'rails_helper'
require 'hyrax/specs/shared_specs/indexers'

RSpec.describe NewspaperIndexer do
  let(:indexer_class) { described_class }
  let!(:resource) { Hyrax.persister.save(resource: Newspaper.new) }

  it_behaves_like 'a Hyrax::Resource indexer'

  it_behaves_like 'a UTK work indexer'
end
