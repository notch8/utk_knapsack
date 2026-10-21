# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'themes/digital_collection/catalog/_search_form.html.erb', type: :view do
  let(:search_params) { { q: 'harbor', f: { has_model_ssim: ['Audio'], resource_type_sim: ['Map'] } } }
  let(:page) { Nokogiri::HTML.fragment(rendered) }
  let(:chosen_field) { page.at_css('input#search-work-type') }
  let(:carried_work_types) { page.css("input[type='hidden'][name*='[has_model_ssim]']:not(#search-work-type)") }

  before do
    Site.instance.update!(available_works: Hyrax.config.registered_curation_concern_types)
    search_state = Blacklight::SearchState.new(search_params, CatalogController.blacklight_config, controller)
    view.extend(SearchWorkTypeHelper)
    without_partial_double_verification do
      allow(view).to receive_messages(search_state:, search_form_action: '/catalog', current_search_parameters: 'harbor')
    end
    render partial: 'themes/digital_collection/catalog/search_form'
  end

  it 'submits the chosen work type again' do
    expect(chosen_field['value']).to eq 'Audio'
  end

  it 'shows the chosen work type on the menu button' do
    expect(page.at_css('#search-work-type-toggle [data-work-type-current]').text).to eq 'Audio'
  end

  it 'leaves the work type out of the carried filters, so a new choice replaces it' do
    expect(carried_work_types).to be_empty
  end

  it 'carries the other filters into the next search' do
    expect(page.at_css("input[type='hidden'][name='f[resource_type_sim][]']")['value']).to eq 'Map'
  end

  context 'with types from advanced search' do
    let(:search_params) { { q: 'harbor', f_inclusive: { has_model_ssim: %w[Audio Video] } } }

    it 'leaves those types out of the carried filters' do
      expect(carried_work_types).to be_empty
    end
  end

  context 'without a work type filter' do
    let(:search_params) { { q: 'harbor' } }

    it 'shows All and submits no work type' do
      expect(page.at_css('#search-work-type-toggle [data-work-type-current]').text).to eq 'All'
      expect(chosen_field['value']).to be_blank
    end
  end
end
