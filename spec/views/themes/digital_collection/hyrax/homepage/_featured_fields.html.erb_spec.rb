# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'themes/digital_collection/hyrax/homepage/_featured_fields.html.erb', type: :view do
  let(:fields) do
    { 'id' => 'w1', 'has_model_ssim' => ['StillImage'], 'title_tesim' => ['Gay Street looking north'],
      'resource_type_tesim' => ['http://id.loc.gov/vocabulary/resourceTypes/img'], 'resource_type_label_tesim' => ['Still image'] }
  end
  let(:featured) { Hyrax::WorkShowPresenter.new(SolrDocument.new(fields), nil) }
  let(:page) { Capybara.string(rendered) }
  let(:summary) { [] }

  before do
    view.lookup_context.prepend_view_paths([Rails.root.join('app', 'views', 'themes', 'digital_collection').to_s,
                                            HykuKnapsack::Engine.root.join('app', 'views', 'themes', 'digital_collection').to_s])
    without_partial_double_verification do
      allow(view).to receive_messages(generate_work_url: '/concern/still_images/w1', block_valkyrie_redirect?: false,
                                      dc_creator_names: [], render_thumbnail_tag: '')
      allow(view).to receive(:dc_summary) { |record| record.is_a?(Blacklight::Document) ? summary.map { |text| strip_tags(text) } : summary }
    end
    render partial: 'themes/digital_collection/hyrax/homepage/featured_fields', locals: { featured: }
  end

  it "badges a featured work with its resource type's label" do
    expect(page).to have_css('.dc-badge', exact_text: 'Still image')
  end

  context 'when no label is indexed for the resource type' do
    let(:fields) { super().except('resource_type_label_tesim') }

    it 'shows no badge rather than the stored URI' do
      expect(page).to have_no_css('.dc-badge')
    end
  end

  context 'with a linked summary' do
    let(:summary) { ['Aid at <a href="https://lib.utk.edu/aid">https://lib.utk.edu/aid</a>.'.html_safe] }

    it 'shows it as plain text' do
      expect(page).to have_css('.dc-featured-desc', exact_text: 'Aid at https://lib.utk.edu/aid.')
      expect(page).to have_no_css('.dc-featured-desc a')
    end
  end
end
