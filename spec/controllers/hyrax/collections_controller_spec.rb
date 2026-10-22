# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::CollectionsController, type: :controller do
  routes { Hyrax::Engine.routes }

  describe '#search_action_path' do
    context "on a collection's show page" do
      let(:path) { URI(controller.send(:search_action_path, f: { resource_type_label_sim: ['Still image'] })) }

      before do
        controller.request.path_parameters = { controller: 'hyrax/collections', action: 'show', id: 'abc-123' }
      end

      it "points a member work's facet link at the catalog search" do
        expect(path.path).to eq '/catalog'
      end

      it 'keeps the facet filter in the link' do
        expect(Rack::Utils.parse_nested_query(path.query)).to include('f' => { 'resource_type_label_sim' => ['Still image'] })
      end
    end
  end
end
