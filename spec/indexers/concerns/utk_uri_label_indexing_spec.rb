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
    allow(UriLabelResolver).to receive(:label_for) { |uri| uri.to_s.match?(%r{\Ahttps?://}i) ? "Label for #{uri}" : uri }
  end

  describe '.uri_properties' do
    it 'includes properties with controlled_values sources from the profile' do
      expect(uri_properties).to include(
        :subject, :spatial, :form, :publication_place, :language, :rdf_type
      )
    end

    it 'excludes properties without controlled_values sources' do
      expect(uri_properties).not_to include(:title, :abstract, :description)
    end

    # A seeded tenant answers `resolvable?` for these, where the test database has no
    # vocabularies and answers false for everything, so the service is stubbed rather
    # than relying on which of the two this runs against.
    it 'excludes properties whose vocabulary is held locally' do
      allow(Hyrax.config.controlled_vocabulary_label_service)
        .to receive(:resolvable?) { |source| %w[rights_statements licenses resource_types].include?(source) }
      described_class.reset_cache!

      expect(described_class.uri_properties).to include(:subject, :spatial)
      expect(described_class.uri_properties).not_to include(:rights_statement, :license, :resource_type)
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

  # The stored URI is the link target and what OAI harvests, so it stays put and the
  # label goes in a companion field, which is where Hyrax indexes a local vocabulary's
  # label and where the catalog and show page read it from.
  it 'writes the label beside the URI rather than over it' do
    doc = index(subject: ['http://id.loc.gov/authorities/subjects/sh12345'])
    expect(doc['subject_tesim']).to eq ['http://id.loc.gov/authorities/subjects/sh12345']
    expect(doc['subject_label_tesim']).to eq ['Label for http://id.loc.gov/authorities/subjects/sh12345']
  end

  # A property declaring a facet key gets a label companion for it too, or the facet
  # lists raw URIs while the row beside it reads as a label.
  context 'with a property indexed to a facet as well as a row' do
    let(:faceting_base) do
      Class.new(base_indexer) do
        def to_solr(*args, **kwargs)
          super.tap { |doc| doc['subject_sim'] = doc['subject_tesim'] if doc.key?('subject_tesim') }
        end
      end
    end
    let(:indexer_class) { Class.new(faceting_base) { include UtkUriLabelIndexing } }

    it 'labels every index key the property declares' do
      doc = index(subject: ['http://id.loc.gov/authorities/subjects/sh1'])

      expect(doc['subject_label_sim']).to eq ['Label for http://id.loc.gov/authorities/subjects/sh1']
      expect(doc['subject_label_tesim']).to eq ['Label for http://id.loc.gov/authorities/subjects/sh1']
      expect(doc['subject_sim']).to eq ['http://id.loc.gov/authorities/subjects/sh1']
    end
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

  it 'handles capitalized URI schemes from Bulkrax' do
    doc = index(subject: ['Http://id.loc.gov/authorities/subjects/sh12345'])
    expect(doc['subject_label_tesim']).to eq ['Label for Http://id.loc.gov/authorities/subjects/sh12345']
  end

  # Positional, so a reader pairing the two fields by index does not shift a label onto
  # the wrong value.
  it 'preserves non-URI values alongside resolved labels' do
    doc = index(subject: ['plain text', 'http://id.loc.gov/authorities/subjects/sh1'])
    expect(doc['subject_tesim']).to eq ['plain text', 'http://id.loc.gov/authorities/subjects/sh1']
    expect(doc['subject_label_tesim']).to eq ['plain text', 'Label for http://id.loc.gov/authorities/subjects/sh1']
  end

  it 'resolves labels across multiple properties' do
    doc = index(
      subject: ['http://id.loc.gov/authorities/subjects/sh1'],
      spatial: ['http://sws.geonames.org/4624443']
    )
    expect(doc['subject_label_tesim']).to eq ['Label for http://id.loc.gov/authorities/subjects/sh1']
    expect(doc['spatial_label_tesim']).to eq ['Label for http://sws.geonames.org/4624443']
  end

  context 'with a resource missing the controlled properties' do
    let(:work_struct) { Struct.new(:title, keyword_init: true) }

    it 'does not raise' do
      expect { index(title: ['No controlled fields here']) }.not_to raise_error
    end
  end

  describe '#resolve_compound_uris' do
    let(:base_indexer) do
      Class.new do
        attr_reader :resource

        def initialize(resource:)
          @resource = resource
        end

        def to_solr(*_args, **_kwargs)
          {
            'creators_json_ss' => [{ 'name' => 'http://id.loc.gov/authorities/names/n123', 'role' => 'Photographer' }].to_json,
            'creators_name_tesim' => ['http://id.loc.gov/authorities/names/n123'],
            'creators_name_sim' => ['http://id.loc.gov/authorities/names/n123'],
            'creators_role_tesim' => ['Photographer'],
            'creators_role_sim' => ['Photographer']
          }
        end
      end
    end

    let(:work_struct) { Struct.new(:title, keyword_init: true) { def try(m) = respond_to?(m) ? send(m) : nil } }

    it 'resolves URIs in compound JSON blobs and searchable fields' do
      doc = index(title: ['Test'])
      parsed = JSON.parse(doc['creators_json_ss'])
      expect(parsed.first['name']).to eq 'Label for http://id.loc.gov/authorities/names/n123'
      expect(parsed.first['role']).to eq 'Photographer'
      expect(doc['creators_name_tesim']).to eq ['Label for http://id.loc.gov/authorities/names/n123']
      expect(doc['creators_name_sim']).to eq ['Label for http://id.loc.gov/authorities/names/n123']
      expect(doc['creators_role_tesim']).to eq ['Photographer']
    end

    context 'when compound values are plain text' do
      let(:base_indexer) do
        Class.new do
          attr_reader :resource

          def initialize(resource:)
            @resource = resource
          end

          def to_solr(*_args, **_kwargs)
            {
              'contributors_json_ss' => [{ 'name' => 'Jane Doe', 'role' => 'Author' }].to_json,
              'contributors_name_tesim' => ['Jane Doe']
            }
          end
        end
      end

      it 'leaves non-URI values unchanged' do
        doc = index(title: ['Test'])
        parsed = JSON.parse(doc['contributors_json_ss'])
        expect(parsed.first['name']).to eq 'Jane Doe'
        expect(doc['contributors_name_tesim']).to eq ['Jane Doe']
      end
    end
  end
end
