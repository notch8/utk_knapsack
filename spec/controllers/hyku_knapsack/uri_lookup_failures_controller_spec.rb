# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::UriLookupFailuresController do
  routes { HykuKnapsack::Engine.routes }
  render_views

  let(:work) do
    Hyrax.persister.save(resource: StillImage.new(title: ['Cites a dead form']))
  end
  let(:uri) { 'http://vocab.getty.edu/aat/30004630' }

  before do
    Hyrax.index_adapter.save(resource: work)
    create(:uri_cache, uri:, status: 'failed', value: nil, reason: 'Not Found(404)', permanent: true,
                       attempts: 1, retry_after: 30.days.from_now)
    UriCitation.create!(tenant: Apartment::Tenant.current, work_id: work.id.to_s, uri:)
  end

  context 'as an admin' do
    before { sign_in create(:admin) }

    it 'lists each failed lookup with the work citing it' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(response.body).to include uri, 'Not Found(404)', 'Cites a dead form'
      expect(response.body).to include "/concern/still_images/#{work.id}"
    end

    it 'marks a permanent failure as needing a fix, with when it is rechecked' do
      UriCache.find_by(uri:).update!(retry_after: 10.days.from_now)

      get :index

      expect(response.body).to include 'Needs fix', '>Recheck<', 'in 10 days'
    end

    it 'shows when a temporary failure will be retried' do
      UriCache.find_by(uri:).update!(permanent: false, retry_after: 5.hours.from_now)

      get :index

      expect(response.body).to include 'Temporary', 'in about 5 hours'
    end

    it 'downloads the same list as CSV' do
      get :index, format: :csv

      expect(response.media_type).to eq 'text/csv'
      expect(CSV.parse(response.body, headers: true).first['uri']).to eq uri
    end

    it 'still renders when one URI is cited by hundreds of works' do
      300.times { UriCitation.create!(tenant: Apartment::Tenant.current, work_id: SecureRandom.uuid, uri:) }

      get :index

      expect(response).to have_http_status(:ok)
      expect(response.body).to include 'and 296 more'
    end

    it 'still renders a full page of failures, each cited by several works' do
      50.times do |n|
        failed = "http://vocab.getty.edu/aat/dead-#{n}"
        create(:uri_cache, uri: failed, status: 'failed', value: nil, reason: 'Not Found(404)', permanent: true)
        5.times { UriCitation.create!(tenant: Apartment::Tenant.current, work_id: SecureRandom.uuid, uri: failed) }
      end

      get :index

      expect(response).to have_http_status(:ok)
    end

    it 'says so when there are no unresolved labels' do
      UriCitation.delete_all

      get :index

      expect(response.body).to include 'No unresolved labels.'
    end
  end

  it 'refuses a user who cannot manage vocabularies' do
    sign_in create(:user)

    get :index

    expect(response).not_to have_http_status(:ok)
  end
end
