# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::HomepageController, type: :controller do
  routes { Hyrax::Engine.routes }

  describe '#index' do
    let(:collections) do
      %w[Alpha Bravo Charlie].map { |title| FactoryBot.valkyrie_create(:hyku_collection, :public, title: [title]) }
    end

    before do
      Hyrax::SolrService.wipe!
      collections
      allow(controller.blacklight_config).to receive(:max_per_page).and_return(2)
    end

    it "lists collections past Blacklight's max_per_page" do
      get :index

      expect(assigns(:collections).map(&:id)).to include(*collections.map { |collection| collection.id.to_s })
    end

    it 'lists every collection whatever page the request names' do
      get :index, params: { page: 2 }

      expect(assigns(:collections).map(&:id)).to include(*collections.map { |collection| collection.id.to_s })
    end
  end
end
