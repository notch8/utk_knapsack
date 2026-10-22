# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'themes/digital_collection/advanced/_advanced_search_facets_as_select.html.erb', type: :view do
  let(:config) do
    Blacklight::Configuration.new.tap do |blacklight|
      blacklight.add_facet_field 'subject_sim', label: 'Subject', if: false
      blacklight.add_facet_field 'subject_label_sim', label: 'Subject'
    end
  end
  let(:items) { ->(*values) { values.map { |value| Blacklight::Solr::Response::Facets::FacetItem.new(value:, hits: 1) } } }
  let(:facets) do
    [Blacklight::Solr::Response::Facets::FacetField.new('subject_sim', items.call('http://id.loc.gov/authorities/names/n79109786')),
     Blacklight::Solr::Response::Facets::FacetField.new('subject_label_sim', items.call('Knoxville (Tenn.)'))]
  end
  let(:page) { Capybara.string(rendered) }

  before do
    blacklight = config
    view.define_singleton_method(:blacklight_config) { blacklight }
    view.define_singleton_method(:blacklight_configuration_context) { Blacklight::Configuration::Context.new(self) }
    without_partial_double_verification do
      allow(view).to receive_messages(facet_field_names: facets.map(&:name), facets_from_request: facets, facet_value_checked?: false)
    end
    render partial: 'themes/digital_collection/advanced/advanced_search_facets_as_select'
  end

  it 'lists a facet the catalog sidebar shows' do
    expect(page).to have_css("select[name='f_inclusive[subject_label_sim][]'] option[value='Knoxville (Tenn.)']")
  end

  it 'leaves out a facet the catalog hides, such as the stored URIs behind a label facet' do
    expect(page).to have_no_css("select[name='f_inclusive[subject_sim][]']")
  end
end
