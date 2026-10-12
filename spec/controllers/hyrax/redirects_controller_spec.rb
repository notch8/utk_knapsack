# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::RedirectsController, type: :controller do
  let(:location) { URI(response.headers['Location']) }

  before do
    allow(Hyrax.config).to receive(:redirects_active?).and_return(true)
    Hyrax::RedirectPath.create!(from_path: '/old-gamble', to_path: '/edgamble',
                                permalink_path: '/collections/abc-123', resource_id: 'abc-123', is_display_url: false)
  end

  it 'carries the query string from an old alias to the display alias' do
    get :show, params: { alias_path: 'old-gamble', locale: 'en', page: '2', f: { subject_sim: ['Tennessee'] } }

    expect(response).to have_http_status(:moved_permanently)
    expect(location.path).to eq '/edgamble'
    expect(Rack::Utils.parse_nested_query(location.query))
      .to eq('locale' => 'en', 'page' => '2', 'f' => { 'subject_sim' => ['Tennessee'] })
  end
end
