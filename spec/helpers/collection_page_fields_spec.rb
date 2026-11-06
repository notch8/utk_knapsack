# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::CollectionsHelper, type: :helper do
  let(:utk_fields) do
    %i[abstract date_created date_issued creators contributors publication_place subject keyword repository language
       spatial coordinates extent form resource_type note rights_statement provider call_number ark]
  end
  let(:values) { {} }
  let(:collection) do
    document = SolrDocument.new({ 'id' => 'c1', 'has_model_ssim' => ['DigitalCollection'],
                                  'schema_version_ssi' => Hyrax::FlexibleSchema.current_schema_id.to_s,
                                  'title_tesim' => ['Images of East Tennessee'] }.merge(values))
    Hyrax::CollectionPresenter.new(document, Ability.new(nil)).tap { |presenter| allow(presenter).to receive(:editor?).and_return(false) }
  end
  let(:page) do
    helper.extend(DigitalCollectionHelper)
    helper.define_singleton_method(:search_state) { Blacklight::SearchState.new({}, CatalogController.blacklight_config) }
    Capybara.string(safe_join(helper.dc_collection_metadata_rows(collection)))
  end
  let(:rows) { page.all('dt').map { |dt| [dt.text.strip, dt.find(:xpath, 'following-sibling::dd[1]').text.squish] } }

  it "lists UTK's collection page fields, in UTK's order, when the profile shows each of them" do
    expect(helper.collection_terms_for(collection, dynamic: true)).to eq utk_fields
  end

  context 'with a collection described the way UTK describes one' do
    let(:values) do
      { 'abstract_tesim' => ['Postcards and photographs of Knoxville.'],
        'date_created_tesim' => ['1791-2007'], 'date_issued_tesim' => ['1925'],
        'creators_name_tesim' => ['Robertson, Ernest Bryan, 1928-2011'],
        'creators_json_ss' => [{ name: 'Robertson, Ernest Bryan, 1928-2011', role: 'Photographer' }].to_json,
        'contributors_name_tesim' => ["World's Fair of 1982 (Knoxville, Tenn.)"],
        'contributors_json_ss' => [{ name: "World's Fair of 1982 (Knoxville, Tenn.)", role: 'Contributor' }].to_json,
        'language_tesim' => ['http://id.loc.gov/vocabulary/iso639-2/eng'], 'language_label_tesim' => ['English'],
        'rights_statement_tesim' => ['http://rightsstatements.org/vocab/CNE/1.0/'],
        'rights_statement_label_tesim' => ['Copyright Not Evaluated'] }
    end

    it "renders each field with a value, in UTK's order, and none without one" do
      expect(rows.map(&:first)).to eq ['Abstract', 'Date Created', 'Date Issued', 'Creator', 'Contributor', 'Language', 'Rights Statement']
    end

    it 'shows creators and contributors with their roles' do
      expect(rows.to_h.values_at('Creator', 'Contributor').join(' ')).to include('Photographer', 'Robertson', "World's Fair of 1982")
    end

    it 'shows controlled values by their labels' do
      expect(rows.to_h.values_at('Language', 'Rights Statement')).to eq ['English', 'Copyright Not Evaluated']
    end
  end

  context 'with a value in every field on the list' do
    let(:controlled) do
      { 'publication_place' => %w[http://id.loc.gov/authorities/names/n79109786 Knoxville],
        'subject' => %w[http://id.loc.gov/authorities/subjects/sh85010156 Architecture],
        'repository' => %w[http://id.loc.gov/authorities/names/n87808088 Special],
        'language' => %w[http://id.loc.gov/vocabulary/iso639-2/eng English],
        'spatial' => %w[http://sws.geonames.org/4634946/ Tennessee],
        'form' => %w[http://vocab.getty.edu/aat/300026816 postcards],
        'resource_type' => ['http://id.loc.gov/vocabulary/resourceTypes/img', 'still image'],
        'rights_statement' => ['http://rightsstatements.org/vocab/CNE/1.0/', 'Copyright Not Evaluated'],
        'provider' => %w[http://id.loc.gov/authorities/names/n80003889 Libraries] }
    end
    let(:values) do
      plain = %w[abstract date_created date_issued keyword coordinates extent note call_number ark].index_with { |field| ["A #{field}"] }
      plain.transform_keys { |field| "#{field}_tesim" }
           .merge(controlled.flat_map { |field, (uri, label)| [["#{field}_tesim", [uri]], ["#{field}_label_tesim", [label]]] }.to_h)
           .merge('creators_name_tesim' => ['Robertson'], 'creators_json_ss' => [{ name: 'Robertson', role: 'Photographer' }].to_json,
                  'contributors_name_tesim' => ['Hyde'], 'contributors_json_ss' => [{ name: 'Hyde', role: 'Contributor' }].to_json)
    end

    it 'renders every field on the list, in its order' do
      expect(rows.map(&:first)).to eq ['Abstract', 'Date Created', 'Date Issued', 'Creator', 'Contributor', 'Publication Place',
                                       'Subject', 'Keyword', 'Repository', 'Language', 'Location', 'Coordinates', 'Extent', 'Form',
                                       'Resource Type', 'Note', 'Rights Statement', 'Provider', 'Library of Congress Classification',
                                       'ARK']
    end

    it 'shows no controlled value by its URI' do
      shown = rows.to_h.values_at('Publication Place', 'Subject', 'Repository', 'Language', 'Location', 'Form', 'Resource Type', 'Provider')

      expect(shown).to eq %w[Knoxville Architecture Special English Tennessee postcards still\ image Libraries]
    end
  end
end
