# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SearchWorkTypeHelper, type: :helper do
  let(:search_params) { { q: 'harbor', f: { has_model_ssim: ['Audio'], resource_type_sim: ['Map'] } } }

  before do
    Site.instance.update!(available_works: %w[Book Audio])
    search_state = Blacklight::SearchState.new(search_params, CatalogController.blacklight_config, controller)
    without_partial_double_verification do
      allow(helper).to receive(:search_state).and_return(search_state)
    end
  end

  describe '#search_work_type_options' do
    it "lists the tenant's enabled types in registration order, labeled as the Work Type facet labels them" do
      expect(helper.search_work_type_options).to eq [%w[Audio Audio], %w[Book Book]]
    end
  end

  describe '#chosen_search_work_type' do
    it 'is the type the search is limited to' do
      expect(helper.chosen_search_work_type).to eq 'Audio'
    end

    context 'with one type from advanced search' do
      let(:search_params) { { f_inclusive: { has_model_ssim: ['Audio'] } } }

      it 'is that type' do
        expect(helper.chosen_search_work_type).to eq 'Audio'
      end
    end

    context 'with several types from advanced search' do
      let(:search_params) { { f_inclusive: { has_model_ssim: %w[Audio Book] } } }

      it 'is none, so the menu shows All' do
        expect(helper.chosen_search_work_type).to be_nil
      end
    end

    context 'without a work type filter' do
      let(:search_params) { { q: 'harbor' } }

      it 'is none' do
        expect(helper.chosen_search_work_type).to be_nil
      end
    end
  end

  describe '#chosen_search_work_type_label' do
    it "is the chosen type's label" do
      expect(helper.chosen_search_work_type_label).to eq 'Audio'
    end

    context 'without a work type filter' do
      let(:search_params) { { q: 'harbor' } }

      it 'is All' do
        expect(helper.chosen_search_work_type_label).to eq 'All'
      end
    end
  end

  describe '#search_params_without_work_type' do
    it 'keeps the other filters and drops the work type' do
      expect(helper.search_params_without_work_type['f']).to eq('resource_type_sim' => ['Map'])
    end

    it 'drops the query, which the search field submits itself' do
      expect(helper.search_params_without_work_type).not_to have_key('q')
    end

    context 'with types from advanced search' do
      let(:search_params) { { f_inclusive: { has_model_ssim: %w[Audio Book], resource_type_sim: %w[Map Atlas] } } }

      it 'drops those types and keeps the other inclusive filters' do
        expect(helper.search_params_without_work_type['f_inclusive']).to eq('resource_type_sim' => %w[Map Atlas])
      end
    end
  end
end
