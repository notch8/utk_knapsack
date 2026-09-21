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
        result = { 'title_tesim' => ['Untouched'] }
        resource.class.members.each do |prop|
          vals = Array(resource.try(prop)).map(&:to_s).select(&:present?)
          result["#{prop}_tesim"] = vals if vals.any?
        end
        result
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
        double(pick: nil)
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

  it 'replaces URI values with labels in _tesim' do
    doc = index(subject: ['http://id.loc.gov/authorities/subjects/sh12345'])
    expect(doc['subject_tesim']).to eq ['Label for http://id.loc.gov/authorities/subjects/sh12345']
  end

  it 'handles multiple URIs on one property' do
    doc = index(subject: [
                  'http://id.loc.gov/authorities/subjects/sh1',
                  'http://id.loc.gov/authorities/names/n2'
                ])
    expect(doc['subject_tesim']).to eq [
      'Label for http://id.loc.gov/authorities/subjects/sh1',
      'Label for http://id.loc.gov/authorities/names/n2'
    ]
  end

  it 'preserves non-URI values alongside resolved labels' do
    doc = index(subject: ['plain text', 'http://id.loc.gov/authorities/subjects/sh1'])
    expect(doc['subject_tesim']).to eq ['plain text', 'Label for http://id.loc.gov/authorities/subjects/sh1']
  end

  it 'resolves labels across multiple properties' do
    doc = index(
      subject: ['http://id.loc.gov/authorities/subjects/sh1'],
      spatial: ['http://sws.geonames.org/4624443']
    )
    expect(doc['subject_tesim']).to eq ['Label for http://id.loc.gov/authorities/subjects/sh1']
    expect(doc['spatial_tesim']).to eq ['Label for http://sws.geonames.org/4624443']
  end

  context 'with a resource missing the controlled properties' do
    let(:work_struct) { Struct.new(:title, keyword_init: true) }

    it 'does not raise' do
      expect { index(title: ['No controlled fields here']) }.not_to raise_error
    end
  end
end
