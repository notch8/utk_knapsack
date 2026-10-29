# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Clicky analytics', type: :request, singletenant: true do
  include Devise::Test::IntegrationHelpers

  let(:doc) { Nokogiri::HTML(response.body) }
  let(:clicky_scripts) { doc.css('script[src="https://static.getclicky.com/js"][data-id="101446845"]') }
  let(:site_id) { '101446845' }

  around do |example|
    original = ENV.fetch('CLICKY_SITE_ID', nil)
    ENV['CLICKY_SITE_ID'] = site_id
    example.run
  ensure
    ENV['CLICKY_SITE_ID'] = original
  end

  before do
    allow_any_instance_of(ApplicationController).to receive(:home_page_theme).and_return('digital_collection')
  end

  it 'loads the site script on the homepage' do
    get '/'

    expect(clicky_scripts.size).to eq(1)
    expect(clicky_scripts.first['async']).not_to be_nil
  end

  it 'loads the site script on search results' do
    get '/catalog', params: { q: 'zzclickynomatch' }

    expect(response).to have_http_status(:ok)

    expect(clicky_scripts.size).to eq(1)
  end

  it 'leaves the dashboard untracked' do
    Hyrax::Group.find_or_create_by!(name: 'admin')
    sign_in FactoryBot.create(:admin)
    get '/dashboard'

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('getclicky')
  end

  context 'without a site ID' do
    let(:site_id) { '' }

    it 'loads no Clicky script' do
      get '/'

      expect(response.body).not_to include('getclicky')
    end
  end
end
