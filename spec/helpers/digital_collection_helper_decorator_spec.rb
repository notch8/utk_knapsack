# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DigitalCollectionHelperDecorator, type: :helper do
  let(:document) do
    SolrDocument.new('id' => 'w1', 'has_model_ssim' => ['Book'], 'creators_name_tesim' => ['Bernstein, Leonard', 'Bernstein, Leonard'],
                     'abstract_tesim' => ['A survey of the river.'], 'creator_tesim' => ['admin@example.com'])
  end
  let(:presenter) { Hyrax::WorkShowPresenter.new(document, nil) }

  describe '#dc_creator_names' do
    it "reads a work page's names from creators, once each, when the profile shows them" do
      allow(helper).to receive(:dc_profile_shows?).with(presenter, :creators).and_return(true)

      expect(helper.dc_creator_names(presenter)).to eq(['Bernstein, Leonard'])
    end

    it 'shows no names, not the plain creator field, when the profile hides creators' do
      allow(helper).to receive(:dc_profile_shows?).with(presenter, :creators).and_return(false)

      expect(helper.dc_creator_names(presenter)).to be_empty
    end

    it 'reads names on a collection page without asking the collection for creators' do
      collection = Hyrax::CollectionPresenter.new(SolrDocument.new('id' => 'c1', 'has_model_ssim' => ['DigitalCollection'],
                                                                   'creators_name_tesim' => ['Hudson River Museum']), nil)
      allow(helper).to receive(:dc_profile_shows?).with(collection, :creators).and_return(true)

      expect(helper.dc_creator_names(collection)).to eq(['Hudson River Museum'])
    end

    it "follows the profile's search results setting for a search result's names" do
      allow(Hyrax.config).to receive(:flexible?).and_return(true)
      allow(helper).to receive(:dc_profile_view_definitions).with(document)
                                                            .and_return({ creators: { 'search_results' => true } }, { creators: { 'search_results' => false } })

      expect(helper.dc_creator_names(document)).to eq(['Bernstein, Leonard'])
      expect(helper.dc_creator_names(document)).to be_empty
    end
  end

  describe '#dc_summary' do
    it "reads a work page's summary from abstract when the profile shows it" do
      allow(helper).to receive(:dc_profile_shows?).with(presenter, :abstract).and_return(true)

      expect(helper.dc_summary(presenter)).to eq(['A survey of the river.'])
    end

    it 'shows no summary when the profile hides abstract' do
      allow(helper).to receive(:dc_profile_shows?).with(presenter, :abstract).and_return(false)

      expect(helper.dc_summary(presenter)).to be_empty
    end

    it "reads a search result's summary from abstract" do
      expect(helper.dc_summary(document)).to eq(['A survey of the river.'])
    end
  end

  describe '#dc_work_shown_elsewhere' do
    it 'leaves the abstract out of the metadata rows, since the summary already shows it' do
      expect(helper.dc_work_shown_elsewhere).to include('.attribute-description', '.attribute-abstract')
    end
  end
end
