# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Error pages', type: :request, singletenant: true do
  let(:doc) { Nokogiri::HTML(response.body) }

  around do |example|
    env_config = Rails.application.env_config
    original = env_config.slice('action_dispatch.show_exceptions', 'action_dispatch.show_detailed_exceptions')
    env_config['action_dispatch.show_exceptions'] = :all
    env_config['action_dispatch.show_detailed_exceptions'] = false
    example.run
  ensure
    env_config.merge!(original)
  end

  it 'renders an unknown path as a 404 inside the site layout' do
    get '/no-such-page'

    expect(response).to have_http_status(:not_found)
    expect(doc.at_css('title').text).to start_with('Page not found')
    expect(doc.css('h1').map { |h| h.text.strip }).to include('Page not found')
    expect(doc.text).to include('The requested page "/no-such-page" could not be found.')
    expect(doc.css('header')).not_to be_empty
    expect(doc.css('form#search-form-header, form[action$="/catalog"]')).not_to be_empty
  end

  it 'wears the digital_collection theme' do
    allow_any_instance_of(ApplicationController).to receive(:home_page_theme).and_return('digital_collection')
    get '/no-such-page'

    expect(response).to have_http_status(:not_found)
    expect(doc.css('footer.utk-footer').size).to eq(1)
  end

  it 'renders a missing work the same way' do
    get '/concern/still_images/no-such-work'

    expect(response).to have_http_status(:not_found)
    expect(doc.css('h1').map { |h| h.text.strip }).to include('Page not found')
  end

  it 'shows who is signed in' do
    user = FactoryBot.create(:user)
    login_as user
    get '/no-such-page'

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include(user.email)
  end

  it 'escapes the requested path' do
    get '/%3Cscript%3Ealert(1)%3C/script%3E'

    expect(response).to have_http_status(:not_found)
    expect(doc.css('script').map(&:text)).not_to include('alert(1)')
  end

  it 'answers a JSON request with the static JSON body' do
    get '/no-such-page.json'

    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq('application/json')
  end

  it 'leaves other errors on the static pages' do
    allow_any_instance_of(HykuKnapsack::IslandoraRedirectsController).to receive(:show).and_raise(StandardError)
    get '/islandora/object/foo:1'

    expect(response).to have_http_status(:internal_server_error)
    expect(response.body).to eq(Rails.public_path.join('500.html').read)
  end

  it 'falls back to the static 404 when the themed page fails' do
    allow_any_instance_of(HykuKnapsack::ErrorsController).to receive(:not_found).and_raise(StandardError)
    get '/no-such-page'

    expect(response).to have_http_status(:not_found)
    expect(response.body).to eq(Rails.public_path.join('404.html').read)
  end

  it 'renders the 404 for a POST without a valid authenticity token' do
    original = ActionController::Base.allow_forgery_protection
    begin
      ActionController::Base.allow_forgery_protection = true
      post '/no-such-page'
    ensure
      ActionController::Base.allow_forgery_protection = original
    end

    expect(response).to have_http_status(:not_found)
    expect(doc.css('h1').map { |h| h.text.strip }).to include('Page not found')
  end

  context 'with several tenants', multitenant: true do
    let(:account) { FactoryBot.build(:account, tenant: 'error-page-tenant') }

    before do
      allow(account).to receive(:persisted?).and_return(true)
      allow(Account).to receive(:from_request).and_return(account)
      allow(Apartment::Tenant).to receive(:switch).and_yield
    end

    it "switches to the request's tenant again for the error page" do
      get '/no-such-page'

      expect(response).to have_http_status(:not_found)
      expect(doc.css('h1').map { |h| h.text.strip }).to include('Page not found')
      expect(Apartment::Tenant).to have_received(:switch).with('error-page-tenant').twice
    end
  end
end
