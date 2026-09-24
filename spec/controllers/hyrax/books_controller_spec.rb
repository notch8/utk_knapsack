# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::BooksController do
  describe '#iiif_manifest_presenter' do
    subject(:presenter) { controller.send(:iiif_manifest_presenter) }

    before do
      allow(controller).to receive(:search_result_document).and_return(SolrDocument.new(id: 'b1', has_model_ssim: ['Book']))
      controller.params = { id: 'b1' }
    end

    it 'is the Book manifest presenter' do
      expect(presenter).to be_a(Hyrax::BookIiifManifestPresenter)
    end

    it 'carries the request base url IiifPrint builds its facet links from' do
      expect(presenter.base_url).to eq 'http://test.host'
    end
  end
end
