# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'themes/digital_collection/catalog/_search_form.html.erb', type: :view do
  let(:search_params) { { q: 'harbor', f: { has_model_ssim: ['Audio'], resource_type_sim: ['Map'] } } }
  let(:page) { Nokogiri::HTML.fragment(rendered) }
  let(:type_select) { page.at_css('select#search-work-type') }

  before do
    Site.instance.update!(available_works: Hyrax.config.registered_curation_concern_types)
    search_state = Blacklight::SearchState.new(search_params, CatalogController.blacklight_config, controller)
    without_partial_double_verification do
      allow(view).to receive_messages(search_state:, search_form_action: '/catalog', current_search_parameters: 'harbor')
    end
    render partial: 'themes/digital_collection/catalog/search_form'
  end

  it 'keeps the chosen work type selected' do
    expect(type_select.at_css('option[selected]')['value']).to eq 'Audio'
  end

  it 'leaves the work type out of the carried filters, so a new choice replaces it' do
    expect(page.at_css("input[type='hidden'][name='f[has_model_ssim][]']")).to be_nil
  end

  it 'carries the other filters into the next search' do
    expect(page.at_css("input[type='hidden'][name='f[resource_type_sim][]']")['value']).to eq 'Map'
  end

  context 'with several work types from advanced search' do
    let(:search_params) { { q: 'harbor', f_inclusive: { has_model_ssim: %w[Audio Video] } } }

    it 'selects All' do
      expect(type_select.at_css('option[selected]')).to be_nil
    end

    it 'leaves those work types out of the carried filters' do
      expect(page.at_css("input[type='hidden'][name^='f_inclusive[has_model_ssim]']")).to be_nil
    end
  end

  context 'without a work type filter' do
    let(:search_params) { { q: 'harbor' } }

    it 'selects All' do
      expect(type_select.at_css('option[selected]')).to be_nil
      expect(type_select.at_css('option').text).to eq 'All'
    end
  end
end
