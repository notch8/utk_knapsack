# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UtkUriLabelIndexing do
  let(:base_indexer) do
    Class.new do
      attr_reader :resource

      def initialize(resource:)
        @resource = resource
      end

      def to_solr(*_args, **_kwargs)
        { 'title_tesim' => ['Untouched'] }
      end
    end
  end

  let(:indexer_class) { Class.new(base_indexer) { include UtkUriLabelIndexing } }

  let(:uri_properties) { described_class.uri_properties }
  let(:work_struct) do
    props = uri_properties
    if props.any?
      Struct.new(*props, keyword_init: true) do
        def try(method)
          respond_to?(method) ? send(method) : nil
        end
      end
    else
      Struct.new(:title, keyword_init: true) do
        def try(method)
          respond_to?(method) ? send(method) : nil
        end
      end
    end
  end

  def index(**props)
    indexer_class.new(resource: work_struct.new(**props)).to_solr
  end

  before do
    described_class.reset_cache!
    allow(UriLabelResolver).to receive(:label_for) { |uri| "Label for #{uri}" }
  end

  describe '.uri_properties' do
    it 'includes properties with controlled_values sources from the profile' do
      expect(uri_properties).to include(
        :subject, :spatial, :form, :publication_place,
        :rights_statement, :license, :language, :rdf_type
      )
    end

    it 'excludes properties without controlled_values sources' do
      expect(uri_properties).not_to include(:title, :abstract, :description)
    end

    it 'returns an empty array when no schema exists' do
      allow(Hyrax::FlexibleSchema).to receive(:order).and_return(
        double(last: nil)
      )
      expect(described_class.uri_properties).to eq []
    end

    it 'caches the result and reuses it for the same schema' do
      first_call = described_class.uri_properties
      expect(Hyrax::FlexibleSchema).to receive(:order).once.and_call_original
      second_call = described_class.uri_properties
      expect(second_call).to equal first_call
    end
  end

  it 'writes label fields for properties with URI values' do
    doc = index(subject: ['http://id.loc.gov/authorities/subjects/sh12345'])
    expect(doc['subject_label_tesim']).to eq ['Label for http://id.loc.gov/authorities/subjects/sh12345']
  end

  it 'handles multiple URIs on one property' do
    doc = index(subject: [
                  'http://id.loc.gov/authorities/subjects/sh1',
                  'http://id.loc.gov/authorities/names/n2'
                ])
    expect(doc['subject_label_tesim']).to eq [
      'Label for http://id.loc.gov/authorities/subjects/sh1',
      'Label for http://id.loc.gov/authorities/names/n2'
    ]
  end

  it 'skips non-URI values' do
    doc = index(subject: ['Doe, John', 'plain text'])
    expect(doc).not_to have_key 'subject_label_tesim'
  end

  it 'resolves only the URI values in a mixed field' do
    doc = index(subject: ['plain text', 'http://id.loc.gov/authorities/subjects/sh1'])
    expect(doc['subject_label_tesim']).to eq ['Label for http://id.loc.gov/authorities/subjects/sh1']
  end

  it 'writes labels for multiple properties' do
    doc = index(
      subject: ['http://id.loc.gov/authorities/subjects/sh1'],
      spatial: ['http://sws.geonames.org/4624443']
    )
    expect(doc['subject_label_tesim']).to eq ['Label for http://id.loc.gov/authorities/subjects/sh1']
    expect(doc['spatial_label_tesim']).to eq ['Label for http://sws.geonames.org/4624443']
  end

  it 'omits label fields when no property has URIs' do
    doc = index(subject: ['plain text'], spatial: ['Nashville, TN'])
    uri_properties.each do |prop|
      expect(doc).not_to have_key "#{prop}_label_tesim"
    end
  end

  it 'leaves the rest of the document alone' do
    doc = index(subject: ['http://example.com/uri'])
    expect(doc['title_tesim']).to eq ['Untouched']
  end

  context 'with a resource missing the controlled properties' do
    let(:work_struct) { Struct.new(:title, keyword_init: true) }

    it 'does not raise' do
      doc = index(title: ['No controlled fields here'])
      expect(doc['title_tesim']).to eq ['Untouched']
    end
  end
end
