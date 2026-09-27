# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UtkUriLabelIndexing do
  let(:indexer_class) { Class.new(base_indexer) { include UtkUriLabelIndexing } }
  let(:resource) { Struct.new(:id, keyword_init: true).new(id: Valkyrie::ID.new('work-1')) }

  let(:base_indexer) do
    solr_doc = document
    indexed = resource
    Class.new do
      define_method(:resource) { indexed }
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
    allow(UriLabelResolver).to receive(:lookup) do |uri|
      "Label for #{uri}" if uri.to_s.match?(%r{\Ahttps?://}i)
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

  context 'when a URI in the compound does not resolve' do
    before do
      resource = instance_double(ActiveTriples::Resource)
      allow(ActiveTriples::Resource).to receive(:new).and_return(resource)
      allow(resource).to receive(:fetch).and_raise(IOError, 'Not Found(404)')
      allow(UriLabelResolver).to receive(:lookup).and_call_original
    end

    it 'indexes the stored URI rather than a failure message' do
      doc = index

      expect(JSON.parse(doc['creators_json_ss']).first).to include('name' => 'http://id.loc.gov/authorities/names/n123')
      expect(doc['creators_name_sim']).to eq ['http://id.loc.gov/authorities/names/n123']
    end

    it 'records that this work cites the URI' do
      index

      expect(UriCitation.where(tenant: Apartment::Tenant.current).pluck(:work_id, :uri))
        .to eq [['work-1', 'http://id.loc.gov/authorities/names/n123']]
    end
  end

  it 'keeps the citations a work had when its indexing fails' do
    UriCitation.create!(tenant: Apartment::Tenant.current, work_id: 'work-1', uri: 'http://example.com/kept')
    failing = Class.new(base_indexer) do
      include UtkUriLabelIndexing
      define_method(:resolve_compound_uris) { |_doc| raise 'indexing failed' }
    end

    expect { failing.new.to_solr }.to raise_error('indexing failed')
    expect(UriCitation.pluck(:uri)).to eq ['http://example.com/kept']
  end

  it 'drops a citation the work no longer makes' do
    UriCitation.create!(tenant: Apartment::Tenant.current, work_id: 'work-1', uri: 'http://example.com/gone')
    UriCitation.create!(tenant: Apartment::Tenant.current, work_id: 'work-2', uri: 'http://example.com/gone')

    index

    expect(UriCitation.pluck(:work_id)).to eq ['work-2']
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
