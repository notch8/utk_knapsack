# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::RedirectToDisplayUrl, type: :controller do
  let(:display_alias) { '/edgamble' }
  let(:location) { URI(response.headers['Location']) }
  let(:carried_query) { Rack::Utils.parse_nested_query(location.query) }

  before do
    allow(Hyrax.config).to receive(:redirects_active?).and_return(true)
    Hyrax::RedirectPath.create!(from_path: permalink, to_path: display_alias, permalink_path: permalink,
                                resource_id: 'abc-123', is_display_url: false)
  end

  describe Hyrax::CollectionsController do
    routes { Hyrax::Engine.routes }

    let(:permalink) { '/collections/abc-123' }

    it 'carries paging, sorting, search and facet params to the display alias' do
      get :show, params: { id: 'abc-123', locale: 'en', page: '2', per_page: '50', sort: 'title_ssi asc',
                           cq: 'gamble', f: { subject_sim: ['Tennessee'] } }

      expect(response).to have_http_status(:moved_permanently)
      expect(location.path).to eq display_alias
      expect(carried_query).to eq('locale' => 'en', 'page' => '2', 'per_page' => '50', 'sort' => 'title_ssi asc',
                                  'cq' => 'gamble', 'f' => { 'subject_sim' => ['Tennessee'] })
    end

    it 'encodes carried values so they cannot inject params of their own' do
      get :show, params: { id: 'abc-123', page: '2&evil=yes' }

      expect(carried_query).to eq('page' => '2&evil=yes')
    end

    it 'redirects to the bare alias when there is no query' do
      get :show, params: { id: 'abc-123' }

      expect(response.headers['Location']).to end_with display_alias
    end
  end

  describe Hyrax::StillImagesController do
    routes { Rails.application.routes }

    let(:permalink) { '/concern/still_images/abc-123' }

    it 'carries the query string to the display alias' do
      get :show, params: { id: 'abc-123', locale: 'en', page: '2' }

      expect(location.path).to eq display_alias
      expect(carried_query).to eq('locale' => 'en', 'page' => '2')
    end
  end
end
