# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'The work type menu in the home page search', type: :request, singletenant: true do
  include Devise::Test::IntegrationHelpers

  let(:doc) { Nokogiri::HTML(response.body) }
  let(:type_select) { doc.at_css('#search-form-header select#search-work-type') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:home_page_theme).and_return('digital_collection')
    Site.instance.update!(available_works: Hyrax.config.registered_curation_concern_types)
  end

  shared_examples 'a work type menu' do
    it 'lists All, then every enabled work type' do
      expect(type_select.css('option').map(&:text)).to eq(
        ['All', 'Still Image', 'Audio', 'Book', 'Compound Object', 'Newspaper', 'Pdf', 'Video']
      )
      expect(type_select.css('option').map { |option| option['value'] }).to eq(
        ['', 'StillImage', 'Audio', 'Book', 'CompoundObject', 'Newspaper', 'Pdf', 'Video']
      )
    end

    it 'filters on the work type facet' do
      expect(type_select['name']).to eq 'f[has_model_ssim][]'
    end

    it 'has a label for screen readers' do
      expect(doc.at_css("label[for='search-work-type']").text.strip).to eq 'Limit search to a work type'
    end

    it 'does not route the search to the dashboard' do
      expect(doc.at_css('#search-form-header [data-search-option]')).to be_nil
    end
  end

  context 'when signed out' do
    before { get root_path }

    it_behaves_like 'a work type menu'
  end

  context 'when the tenant has only some work types enabled' do
    before do
      Site.instance.update!(available_works: %w[Book Audio])
      get root_path
    end

    it 'lists only the enabled types, in registration order' do
      expect(type_select.css('option').map(&:text)).to eq %w[All Audio Book]
    end
  end

  context 'when searching the catalog with a work type chosen', clean_repo: true do
    def indexed_open(resource)
      saved = Hyrax.persister.save(resource:)
      Hyrax::VisibilityWriter.new(resource: saved).assign_access_for(visibility: 'open')
      saved.permission_manager.acl.save
      Hyrax.index_adapter.save(resource: saved)
      saved
    end

    before do
      indexed_open(Audio.new(title: ['Harbor field recording']))
      indexed_open(Book.new(title: ['Harbor history']))
      get search_catalog_path(q: 'harbor', f: { has_model_ssim: ['Audio'] })
    end

    it 'returns only that type, under a removable Work Type filter, with the type still chosen' do
      expect(response.body).to include('Harbor field recording')
      expect(response.body).not_to include('Harbor history')
      expect(doc.at_css('#appliedParams .filter-has_model_ssim').text.squish).to include('Work Type', 'Audio')
      expect(doc.at_css('#appliedParams .filter-has_model_ssim a.remove')).to be_present
      expect(type_select.at_css('option[selected]')['value']).to eq 'Audio'
    end
  end

  context 'when signed in' do
    before do
      sign_in FactoryBot.create(:user)
      get root_path
    end

    it_behaves_like 'a work type menu'
  end
end
