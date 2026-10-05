# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'hyrax/base/_file_manager_actions.html.erb', type: :view do
  before do
    stub_template 'hyrax/base/_file_manager_resource_form.html.erb' => ''
    # Resolving the tag for real builds application.js, which this bundle cannot
    # compile: the knapsack resolves blacklight_advanced_search 8.0.0, which
    # ships none of the assets it requires. That the asset exists and is set to
    # ship is guarded in spec/initializers/knapsack_assets_spec.rb.
    without_partial_double_verification do
      allow(view).to receive(:javascript_include_tag) { |path| tag.script(src: path) }
    end
    render partial: 'hyrax/base/file_manager_actions'
  end

  let(:page) { Nokogiri::HTML.fragment(rendered) }
  let(:button) { page.at_css("[data-action='sequence-sort-action']") }

  it 'offers a sequence sort' do
    expect(button.text).to eq 'Sort by sequence'
  end

  it 'explains where members without a sequence land' do
    expect(page.at_css('#sequence-sort-hint').text).to eq(
      'Order members by ascending sequence. Members without a sequence move to the end, keeping their current order.'
    )
  end

  it 'points the button at that explanation, so it is not sighted-only' do
    expect(button['aria-describedby']).to eq 'sequence-sort-hint'
  end

  it 'carries a live region for the sort to announce itself in' do
    status = page.at_css('[data-sequence-sort-status]')

    expect(status['aria-live']).to eq 'polite'
    expect(status['data-message']).to eq 'Members reordered by sequence.'
  end

  it 'keeps the alphabetical sort Hyrax ships' do
    expect(page.at_css("[data-action='alpha-sort-action']")).to be_present
  end

  it 'keeps the save action Hyrax ships' do
    expect(page.at_css("[data-action='save-actions']")).to be_present
  end

  it 'loads the script that binds the sequence sort' do
    expect(page.at_css('script')['src']).to eq 'hyku_knapsack/file_manager_sequence_sort'
  end
end
