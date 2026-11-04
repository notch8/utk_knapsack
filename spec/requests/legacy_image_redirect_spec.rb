# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Legacy image URLs', type: :request, singletenant: true do
  let(:id) { '26b6e244-2f2c-4eaf-adf5-f8b8b5fcc08a' }
  let(:parent_id) { '62c35556-6f5e-43b8-82f5-d71722f17ad3' }

  it 'permanently redirects a legacy image to the still image with the same id' do
    get "/concern/images/#{id}"

    expect(response).to have_http_status(:moved_permanently)
    expect(URI(response.location).path).to eq("/concern/still_images/#{id}")
  end

  it 'keeps the query string' do
    get "/concern/images/#{id}?locale=en"

    expect(URI(response.location).request_uri).to eq("/concern/still_images/#{id}?locale=en")
  end

  it 'keeps nested paths and extensions' do
    get "/concern/images/#{id}/manifest.json"

    expect(URI(response.location).path).to eq("/concern/still_images/#{id}/manifest.json")
  end

  it 'redirects a legacy image shown in the context of its parent' do
    get "/concern/parent/#{parent_id}/images/#{id}"

    expect(response).to have_http_status(:moved_permanently)
    expect(URI(response.location).path).to eq("/concern/parent/#{parent_id}/still_images/#{id}")
  end
end
