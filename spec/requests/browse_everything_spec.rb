# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Browse Everything', type: :request, singletenant: true do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    Hyrax::Group.find_or_create_by!(name: 'admin')
    FactoryBot.create(:admin)
  end
  let(:depositor) do
    FactoryBot.create(:user).tap { |user| FactoryBot.valkyrie_create(:hyrax_admin_set, :with_permission_template, user:) }
  end
  let(:s3) { { s3: { bucket: 'utk-ingest', region: 'us-east-2' } } }
  let(:listing) do
    { contents: [{ key: 'burial_001.tif', size: 10, last_modified: Time.current }], common_prefixes: [] }
  end

  around do |example|
    original = BrowseEverything.config.to_h
    example.run
  ensure
    BrowseEverything.configure(original)
    Aws.config.delete(:s3)
  end

  before do
    BrowseEverything.configure(s3)
    Aws.config[:s3] = { stub_responses: { list_objects: listing } }
  end

  def resolve
    post '/browse/resolve', params: { selected_files: ['s3:burial_001.tif'] }, as: :json
  end

  context 'when logged out' do
    it 'does not list the bucket' do
      get '/browse/s3', xhr: true

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).not_to include('burial_001.tif')
    end

    it 'does not sign a download link' do
      resolve

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).not_to include('X-Amz-Signature')
    end
  end

  context 'when signed in without admin' do
    before { sign_in depositor }

    it 'does not list the bucket' do
      get '/browse/s3', xhr: true

      expect(response).not_to be_successful
      expect(response.body).not_to include('burial_001.tif')
    end

    it 'does not sign a download link' do
      resolve

      expect(response.body).not_to include('X-Amz-Signature')
    end

    it 'offers no cloud files on the importer' do
      get '/importers/new'

      expect(response).to be_successful
      expect(response.body).not_to include('data-toggle="browse-everything"')
    end
  end

  context 'when signed in as an admin' do
    before { sign_in admin }

    it 'lists the bucket' do
      get '/browse/s3', xhr: true

      expect(response).to be_successful
      expect(response.body).to include('burial_001.tif')
    end

    it 'opens the picker on the bucket' do
      get '/browse/', xhr: true

      expect(response.body).to include('burial_001.tif', 'ev-cancel')
    end

    it 'explains in the picker when the bucket cannot be listed' do
      Aws.config[:s3] = { stub_responses: { list_objects: 'NoSuchBucket' } }
      get '/browse/', xhr: true

      expect(response).to be_successful
      expect(CGI.unescapeHTML(response.body)).to include(I18n.t('browse_everything.provider_error.message'), 'ev-cancel')
      expect(response.body).to include('id="beModalLabel"')
    end

    it 'signs a download link for the selected file' do
      resolve

      expect(response.parsed_body.first['url']).to include('utk-ingest', 'burial_001.tif', 'X-Amz-Signature')
    end

    it 'offers cloud files on the importer' do
      get '/importers/new'

      expect(response.body).to include('data-toggle="browse-everything"')
    end

    it 'offers no cloud files on the importer without a provider' do
      BrowseEverything.configure({})
      get '/importers/new'

      expect(response.body).not_to include('data-toggle="browse-everything"')
    end

    it 'keeps cloud files off the work form' do
      expect(Hyrax.config.browse_everything?).to be_falsey
    end
  end
end
