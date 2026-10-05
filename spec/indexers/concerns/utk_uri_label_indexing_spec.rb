# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UtkUriLabelIndexing do
  let(:indexer_class) { Class.new(base_indexer) { include UtkUriLabelIndexing } }
  let(:resource) { Struct.new(:title, keyword_init: true).new(title: ['Test']) }

  let(:base_indexer) do
    solr_doc = document
    Class.new do
      define_method(:to_solr) { |*_args, **_kwargs| solr_doc.deep_dup }
    end
  end

  let(:document) do
    {
      'creators_json_ss' => [{ 'name' => 'http://id.loc.gov/authorities/names/n123',
                               'role' => 'Photographer' }].to_json,
      'creators_name_tesim' => ['http://id.loc.gov/authorities/names/n123'],
      'creators_name_sim' => ['http://id.loc.gov/authorities/names/n123'],
      'creators_role_tesim' => ['Photographer']
    }
  end

  before do
    allow(UriLabelResolver).to receive(:label_for) do |uri|
      uri.to_s.match?(%r{\Ahttps?://}i) ? "Label for #{uri}" : uri
    end
  end

  def index
    indexer_class.new.to_solr
  end

  it 'resolves a URI inside the compound blob' do
    expect(JSON.parse(index['creators_json_ss']).first)
      .to include('name' => 'Label for http://id.loc.gov/authorities/names/n123',
                  'role' => 'Photographer')
  end

  # The blob is what the show page renders, and these are what the catalog facets and
  # search read, so both have to carry the same resolved value.
  it 'resolves the searchable fields derived from the blob' do
    doc = index

    expect(doc['creators_name_tesim']).to eq ['Label for http://id.loc.gov/authorities/names/n123']
    expect(doc['creators_name_sim']).to eq ['Label for http://id.loc.gov/authorities/names/n123']
  end

  # A derived field the schema never declared is not invented here, or the document
  # gains a key nothing reads and Solr has no dynamic rule for.
  it 'leaves a derived field the document does not already have' do
    expect(index).not_to have_key 'creators_role_sim'
  end

  context 'with plain text in the compound' do
    let(:document) do
      {
        'contributors_json_ss' => [{ 'name' => 'Jane Doe', 'role' => 'Author' }].to_json,
        'contributors_name_tesim' => ['Jane Doe']
      }
    end

    it 'leaves the values alone' do
      doc = index

      expect(JSON.parse(doc['contributors_json_ss']).first).to include('name' => 'Jane Doe')
      expect(doc['contributors_name_tesim']).to eq ['Jane Doe']
    end
  end

  context 'with no compound field' do
    let(:document) { { 'title_tesim' => ['Test'] } }

    it 'does not raise' do
      expect { index }.not_to raise_error
    end
  end
end
