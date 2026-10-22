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

  context "for a member work listed on its collection's show page" do
    let(:catalog_fields) do
      Blacklight::Configuration.new.tap do |blacklight|
        blacklight.add_index_field 'abstract_tesim', label: 'Abstract'
        blacklight.add_index_field 'creator_tesim', label: 'Creator'
        blacklight.add_show_field 'subject_tesim', label: 'Subject'
      end
    end
    let(:member_work) do
      SolrDocument.new('id' => 'w2', 'abstract_tesim' => ['A survey.'], 'creator_tesim' => ['Wiley, Catherine'],
                       'subject_tesim' => ['http://id.loc.gov/authorities/names/n79109786'])
    end

    before do
      blacklight = catalog_fields
      helper.define_singleton_method(:blacklight_config) { blacklight }
      helper.define_singleton_method(:blacklight_configuration_context) { Blacklight::Configuration::Context.new(self) }
      allow(helper).to receive_messages(action_name: 'show', document_index_view_type: :list, dc_part_of_links: nil)
    end

    describe '#dc_result_fields' do
      it 'lists the fields catalog search results show' do
        expect(helper.dc_result_fields(member_work).map(&:first)).to eq %i[abstract creator]
      end

      it 'leaves out a field only the show page shows' do
        expect(helper.dc_result_fields(member_work).map(&:first)).not_to include(:subject)
      end
    end

    describe '#dc_creator_names' do
      it 'lists the creator, since catalog search results show the creator field' do
        expect(helper.dc_creator_names(member_work)).to eq ['Wiley, Catherine']
      end
    end
  end

  describe '#dc_work_shown_elsewhere' do
    it 'leaves the abstract out of the metadata rows, since the summary already shows it' do
      expect(helper.dc_work_shown_elsewhere).to include('.attribute-description', '.attribute-abstract')
    end
  end
end
