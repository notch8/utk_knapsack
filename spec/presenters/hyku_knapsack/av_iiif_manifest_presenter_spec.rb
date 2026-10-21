# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::AvIiifManifestPresenter do
  def search_service_for(controller)
    presenter = controller.iiif_manifest_presenter_class.new(SolrDocument.new(id: 'abc123'))
    presenter.hostname = 'example.com'
    presenter.search_service
  end

  it 'leaves IIIF search out of Audio and Video manifests' do
    expect([Hyrax::AudiosController, Hyrax::VideosController].map { |c| search_service_for(c) }).to all(be_nil)
  end

  it 'keeps IIIF search for other work types' do
    expect(search_service_for(Hyrax::StillImagesController)).to end_with '/catalog/abc123/iiif_search'
  end
end
