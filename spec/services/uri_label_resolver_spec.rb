# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/NestedGroups
RSpec.describe UriLabelResolver do
  let(:graph) { RDF::Graph.new }

  def load_fixture(filename, into: graph)
    format = case File.extname(filename)
             when '.nt' then :ntriples
             when '.rdf' then :rdfxml
             when '.ttl' then :ttl
             end

    path = Rails.root.join('..', 'spec', 'fixtures', 'rdf_data', filename)
    File.open(path) do |file|
      RDF::Reader.for(format).new(file) { |reader| reader.each_statement { |s| into << s } }
    end
  end

  def stub_remote_fetch(fixture_file)
    allow(ActiveTriples::Resource).to receive(:new).and_wrap_original do |method, uri|
      resource = method.call(uri)
      load_fixture(fixture_file, into: resource.graph)
      allow(resource).to receive(:fetch).and_return(resource)
      resource
    end
  end

  before do
    allow(UriCache).to receive(:find_by).and_return(nil)
    allow(UriCache).to receive(:create!).and_return(true)
  end

  describe '.label_for' do
    context 'when the value is not a URI' do
      it 'returns the value unchanged' do
        expect(described_class.label_for('Doe, John')).to eq 'Doe, John'
      end
    end

    context 'when the URI is cached' do
      let(:uri) { 'http://id.loc.gov/authorities/names/n2017180154' }

      before do
        cache = instance_double(UriCache, value: 'University of Tennessee')
        allow(UriCache).to receive(:find_by).with(uri:).and_return(cache)
      end

      it 'returns the cached value' do
        expect(described_class.label_for(uri)).to eq 'University of Tennessee'
      end
    end

    context 'from the Library of Congress' do
      context 'example 1 (https URI, fixture subject is http)' do
        let(:uri) { 'https://id.loc.gov/authorities/names/n79007751' }

        before { stub_remote_fetch('loc_1.nt') }

        it 'resolves to the English label' do
          expect(described_class.label_for(uri)).to eq 'New York (N.Y.)'
        end
      end

      context 'example 2 (sameAs redirect, subject path differs)' do
        let(:uri) { 'http://id.loc.gov/authorities/subjects/sj96006364' }

        before { stub_remote_fetch('loc_2.nt') }

        it 'resolves to the English label' do
          expect(described_class.label_for(uri)).to eq 'Water power'
        end
      end

      context 'example 3 (.html suffix in URI)' do
        let(:uri) { 'https://id.loc.gov/authorities/subjects/sh85088046.html' }

        before { stub_remote_fetch('loc_3.nt') }

        it 'resolves to the English label' do
          expect(described_class.label_for(uri)).to eq 'Motion picture film collections'
        end
      end

      context 'example 4 (deleted authority)' do
        let(:uri) { 'http://id.loc.gov/authorities/subjects/sh2009007848' }
        let(:expected) do
          "#{uri} (Failed to load URI) - This authority record has been deleted because it is not a valid heading."
        end

        before { stub_remote_fetch('loc_4.nt') }

        it 'returns the deletion note' do
          expect(described_class.label_for(uri)).to eq expected
        end
      end

      context 'UT (cache integration)' do
        let(:uri) { 'http://id.loc.gov/authorities/names/n2017180154' }

        before do
          allow(UriCache).to receive(:find_by).and_call_original
          allow(UriCache).to receive(:create!).and_call_original
          stub_remote_fetch('loc_ut.nt')
        end

        it 'caches the resolved label' do
          expect { described_class.label_for(uri) }
            .to change { UriCache.where(uri:).count }.from(0).to(1)
          expect(UriCache.find_by(uri:).value).to eq 'University of Tennessee'
        end
      end
    end

    context 'from the Getty' do
      let(:uri) { 'http://vocab.getty.edu/page/aat/300022208' }

      before { stub_remote_fetch('getty.nt') }

      it 'rewrites /page/ to / for the fetch URL' do
        captured_uri = nil
        allow(ActiveTriples::Resource).to receive(:new).and_wrap_original do |method, rdf_uri|
          captured_uri = rdf_uri.to_s
          resource = method.call(rdf_uri)
          load_fixture('getty.nt', into: resource.graph)
          allow(resource).to receive(:fetch).and_return(resource)
          resource
        end
        described_class.label_for(uri)
        expect(captured_uri).to eq 'http://vocab.getty.edu/aat/300022208'
      end

      it 'resolves to the English label' do
        expect(described_class.label_for(uri)).to eq 'Postmodern'
      end
    end

    context 'from GeoNames' do
      let(:uri) { 'http://sws.geonames.org/4624443' }

      before { stub_remote_fetch('geonames.rdf') }

      it 'resolves to the English label via geonames:name predicate' do
        expect(described_class.label_for(uri)).to eq 'Gatlinburg'
      end
    end

    context 'from Wikidata' do
      context 'example 1 (entity URI)' do
        let(:uri) { 'https://www.wikidata.org/entity/Q85304029' }

        before { stub_remote_fetch('wikidata_1.nt') }

        it 'resolves to the English label' do
          expect(described_class.label_for(uri)).to eq 'Dorothy Doolittle'
        end
      end

      context 'example 2 (redirect in RDF)' do
        let(:uri) { 'http://www.wikidata.org/entity/Q107881652' }

        before { stub_remote_fetch('wikidata_2.nt') }

        it 'resolves to the English label' do
          expect(described_class.label_for(uri)).to eq "Tennessee Volunteers men's tennis"
        end
      end

      context 'example 3 (/wiki/ path instead of /entity/)' do
        let(:uri) { 'https://www.wikidata.org/wiki/Q61779863' }

        before { stub_remote_fetch('wikidata_3.nt') }

        it 'rewrites /wiki/ to /entity/' do
          captured_uri = nil
          allow(ActiveTriples::Resource).to receive(:new).and_wrap_original do |method, rdf_uri|
            captured_uri = rdf_uri.to_s
            resource = method.call(rdf_uri)
            load_fixture('wikidata_3.nt', into: resource.graph)
            allow(resource).to receive(:fetch).and_return(resource)
            resource
          end
          described_class.label_for(uri)
          expect(captured_uri).to include('/entity/')
          expect(captured_uri).not_to include('/wiki/')
        end

        it 'resolves to the English label' do
          expect(described_class.label_for(uri)).to eq 'Karen Weekly'
        end
      end
    end

    context 'from Homosaurus' do
      let(:uri) { 'https://homosaurus.org/v3/homoit0000070' }

      before { stub_remote_fetch('homosaurus.nt') }

      it 'resolves to the English label' do
        expect(described_class.label_for(uri)).to eq 'LGBTQ+ artists'
      end
    end

    context 'from RightsStatements' do
      let(:uri) { 'http://rightsstatements.org/vocab/InC/1.0/' }

      context 'via local QA authority' do
        before do
          authority = instance_double(Qa::Authorities::Local::FileBasedAuthority)
          allow(Qa::Authorities::Local).to receive(:subauthority_for)
            .with('rights_statements').and_return(authority)
          allow(authority).to receive(:find).with(uri).and_return('term' => 'In Copyright')
        end

        it 'resolves from local QA' do
          expect(described_class.label_for(uri)).to eq 'In Copyright'
        end
      end

      context 'via remote when local QA has no term' do
        before do
          authority = instance_double(Qa::Authorities::Local::FileBasedAuthority)
          allow(Qa::Authorities::Local).to receive(:subauthority_for)
            .with('rights_statements').and_return(authority)
          allow(authority).to receive(:find).with(uri).and_return('term' => nil)
          stub_remote_fetch('rights.ttl')
        end

        it 'falls back to RDF and resolves the English label' do
          expect(described_class.label_for(uri)).to eq 'In Copyright'
        end
      end
    end

    context 'from Creative Commons' do
      let(:uri) { 'http://creativecommons.org/licenses/by-nc/4.0/' }

      context 'via local QA authority' do
        before do
          authority = instance_double(Qa::Authorities::Local::FileBasedAuthority)
          allow(Qa::Authorities::Local).to receive(:subauthority_for)
            .with('licenses').and_return(authority)
          allow(authority).to receive(:find).with(uri)
                                            .and_return('term' => 'Attribution-NonCommercial 4.0 International')
        end

        it 'resolves from local QA' do
          expect(described_class.label_for(uri)).to eq 'Attribution-NonCommercial 4.0 International'
        end
      end

      context 'via remote when local QA has no term' do
        before do
          authority = instance_double(Qa::Authorities::Local::FileBasedAuthority)
          allow(Qa::Authorities::Local).to receive(:subauthority_for)
            .with('licenses').and_return(authority)
          allow(authority).to receive(:find).with(uri).and_return('term' => nil)
          stub_remote_fetch('licenses.rdf')
        end

        it 'falls back to RDF and resolves the English label' do
          expect(described_class.label_for(uri)).to eq 'Attribution-NonCommercial 4.0 International'
        end
      end
    end

    context 'when the remote fetch fails' do
      let(:uri) { 'http://test.uri/broken' }

      before do
        resource = instance_double(ActiveTriples::Resource)
        allow(ActiveTriples::Resource).to receive(:new).and_return(resource)
        allow(resource).to receive(:fetch).and_raise(StandardError, 'connection refused')
      end

      it 'returns the URI with an error annotation' do
        expect(Rails.logger).to receive(:error).with('Failed to load RDF data: connection refused')
        expect(described_class.label_for(uri)).to eq 'http://test.uri/broken (Failed to load URI)'
      end
    end

    context 'when the remote returns no label' do
      let(:uri) { 'http://example.com/no-label' }

      before do
        allow(ActiveTriples::Resource).to receive(:new).and_wrap_original do |method, rdf_uri|
          resource = method.call(rdf_uri)
          allow(resource).to receive(:fetch).and_return(resource)
          resource
        end
      end

      it 'returns the URI with a no-label annotation' do
        expect(described_class.label_for(uri)).to eq 'http://example.com/no-label (No label found)'
      end
    end
    describe 'pick_english language tag handling' do
      it 'picks en-us labels (Getty convention)' do
        objects = [
          RDF::Literal.new('Postmodernisme', language: :nl),
          RDF::Literal.new('Postmodern', language: :'en-us'),
          RDF::Literal.new('Posmoderno', language: :es)
        ]
        result = described_class.send(:pick_english, objects)
        expect(result).to eq 'Postmodern'
      end

      it 'picks en-gb labels' do
        objects = [
          RDF::Literal.new('Farbe', language: :de),
          RDF::Literal.new('Colour', language: :'en-GB')
        ]
        result = described_class.send(:pick_english, objects)
        expect(result).to eq 'Colour'
      end

      it 'picks plain en labels' do
        objects = [
          RDF::Literal.new('Eau', language: :fr),
          RDF::Literal.new('Water power', language: :en)
        ]
        result = described_class.send(:pick_english, objects)
        expect(result).to eq 'Water power'
      end

      it 'returns nil when no English label exists' do
        objects = [
          RDF::Literal.new('Wasser', language: :de),
          RDF::Literal.new('Eau', language: :fr)
        ]
        expect(described_class.send(:pick_english, objects)).to be_nil
      end
    end
  end
end
# rubocop:enable RSpec/NestedGroups
