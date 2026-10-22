# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ThemeHelperDecorator, type: :helper do
  let(:uri) { 'http://id.loc.gov/vocabulary/resourceTypes/img' }
  let(:fields) do
    { 'id' => 'w1', 'has_model_ssim' => ['StillImage'], 'human_readable_type_tesim' => ['Still Image'],
      'resource_type_tesim' => [uri], 'resource_type_label_tesim' => ['Still image'] }
  end
  let(:presenter) { Hyrax::WorkShowPresenter.new(SolrDocument.new(fields), nil) }

  describe '#theme_type_label' do
    it "shows a work's resource type by its label" do
      expect(helper.theme_type_label(presenter)).to eq 'Still image'
    end

    context 'when no label is indexed for the resource type' do
      let(:fields) { super().except('resource_type_label_tesim') }

      it 'shows the work type name rather than the stored URI' do
        expect(helper.theme_model_label(presenter)).to be_present
        expect(helper.theme_type_label(presenter)).to eq helper.theme_model_label(presenter)
      end
    end
  end

  describe '#theme_resource_type_label' do
    it "reads a search result's resource type label" do
      expect(helper.theme_resource_type_label(SolrDocument.new(fields))).to eq 'Still image'
    end

    it 'is blank, not the stored URI, when no label is indexed' do
      expect(helper.theme_resource_type_label(SolrDocument.new(fields.except('resource_type_label_tesim')))).to be_nil
    end

    it 'is blank when the term did not resolve and the stored URI was indexed as its label' do
      expect(helper.theme_resource_type_label(SolrDocument.new(fields.merge('resource_type_label_tesim' => [uri])))).to be_nil
    end
  end
end
