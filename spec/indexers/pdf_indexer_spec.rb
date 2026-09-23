# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource Pdf`
require 'rails_helper'
require 'hyrax/specs/shared_specs/indexers'

RSpec.describe PdfIndexer do
  let(:indexer_class) { described_class }
  let!(:resource) { Hyrax.persister.save(resource: Pdf.new) }

  it_behaves_like 'a Hyrax::Resource indexer'

  it_behaves_like 'a UTK work indexer'
end
