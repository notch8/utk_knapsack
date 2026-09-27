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

  def stub_fetch_error(message)
    resource = instance_double(ActiveTriples::Resource)
    allow(ActiveTriples::Resource).to receive(:new).and_return(resource)
    allow(resource).to receive(:fetch).and_raise(IOError, message)
  end

  describe '.lookup' do
    context 'when the value is not a URI' do
      it 'returns nil' do
        expect(described_class.lookup('Doe, John')).to be_nil
      end
    end

    context 'when the URI is cached' do
      let(:uri) { 'http://id.loc.gov/authorities/names/n2017180154' }

      before { create(:uri_cache, uri:, value: 'University of Tennessee') }

      it 'returns the cached value without fetching' do
        expect(ActiveTriples::Resource).not_to receive(:new)

        expect(described_class.lookup(uri)).to eq 'University of Tennessee'
      end
    end

    context 'when the URI failed and its wait has not passed' do
      let(:uri) { 'http://vocab.getty.edu/aat/30004630' }

      before do
        create(:uri_cache, uri:, status: 'failed', value: nil, reason: 'Not Found(404)',
                           retry_after: 1.day.from_now)
      end

      it 'returns nil without fetching' do
        expect(ActiveTriples::Resource).not_to receive(:new)

        expect(described_class.lookup(uri)).to be_nil
      end
    end

    context 'when the URI failed and its wait has passed' do
      let(:uri) { 'http://vocab.getty.edu/page/aat/300022208' }

      before do
        create(:uri_cache, uri:, status: 'failed', value: nil, reason: '(499)', attempts: 1,
                           retry_after: 1.minute.ago)
        stub_remote_fetch('getty.nt')
      end

      it 'fetches again and records the label' do
        expect(described_class.lookup(uri)).to eq 'Postmodern'
        expect(UriCache.find_by(uri:)).to have_attributes(status: 'resolved', value: 'Postmodern', attempts: 0)
      end
    end

    context 'when the remote answers 404' do
      let(:uri) { 'http://sws.geonames.org/4654856/about.rdf/about.rdf' }

      before { stub_fetch_error("<#{uri}>: Not Found(404)") }

      it 'records a permanent failure' do
        expect(described_class.lookup(uri)).to be_nil
        expect(UriCache.find_by(uri:)).to have_attributes(status: 'failed', permanent: true,
                                                          reason: "<#{uri}>: Not Found(404)")
      end
    end

    context 'when the remote answers 404 in the short error format' do
      let(:uri) { 'http://vocab.getty.edu/aat/30004630' }

      before { stub_fetch_error("<#{uri}>: 404") }

      it 'records a permanent failure' do
        expect(described_class.lookup(uri)).to be_nil
        expect(UriCache.find_by(uri:)).to have_attributes(status: 'failed', permanent: true)
      end
    end

    context 'when the remote answers with something that is not RDF' do
      let(:uri) { 'https://example.org/a-web-page' }

      before do
        resource = instance_double(ActiveTriples::Resource)
        allow(ActiveTriples::Resource).to receive(:new).and_return(resource)
        allow(resource).to receive(:fetch).and_raise(RDF::FormatError, 'unknown RDF format: {:content_type=>"text/html"}')
      end

      it 'records a permanent failure' do
        expect(described_class.lookup(uri)).to be_nil
        expect(UriCache.find_by(uri:)).to have_attributes(status: 'failed', permanent: true)
      end
    end

    context 'when the remote answers 499' do
      let(:uri) { 'http://vocab.getty.edu/aat/300264679' }

      before { stub_fetch_error('<https://vocab.getty.edu/download/nt?uri=http://vocab.getty.edu/aat/300264679>: (499)') }

      it 'records a temporary failure' do
        expect(described_class.lookup(uri)).to be_nil
        expect(UriCache.find_by(uri:)).to have_attributes(status: 'failed', permanent: false, attempts: 1)
      end
    end

    context 'when the fetch times out' do
      let(:uri) { 'http://vocab.getty.edu/aat/300264679' }

      before do
        resource = instance_double(ActiveTriples::Resource)
        allow(ActiveTriples::Resource).to receive(:new).and_return(resource)
        allow(resource).to receive(:fetch).and_raise(Net::ReadTimeout)
      end

      it 'records a temporary failure' do
        expect(described_class.lookup(uri)).to be_nil
        expect(UriCache.find_by(uri:)).to have_attributes(status: 'failed', permanent: false)
      end
    end

    context 'from the Library of Congress' do
      context 'example 1 (https URI, fixture subject is http)' do
        let(:uri) { 'https://id.loc.gov/authorities/names/n79007751' }

        before { stub_remote_fetch('loc_1.nt') }

        it 'resolves to the English label' do
          expect(described_class.lookup(uri)).to eq 'New York (N.Y.)'
        end
      end

      context 'example 2 (sameAs redirect, subject path differs)' do
        let(:uri) { 'http://id.loc.gov/authorities/subjects/sj96006364' }

        before { stub_remote_fetch('loc_2.nt') }

        it 'resolves to the English label' do
          expect(described_class.lookup(uri)).to eq 'Water power'
        end
      end

      context 'example 3 (.html suffix in URI)' do
        let(:uri) { 'https://id.loc.gov/authorities/subjects/sh85088046.html' }

        before { stub_remote_fetch('loc_3.nt') }

        it 'resolves to the English label' do
          expect(described_class.lookup(uri)).to eq 'Motion picture film collections'
        end
      end

      context 'example 4 (deleted authority)' do
        let(:uri) { 'http://id.loc.gov/authorities/subjects/sh2009007848' }

        before { stub_remote_fetch('loc_4.nt') }

        it 'records the deletion note as a permanent failure, not a label' do
          expect(described_class.lookup(uri)).to be_nil
          expect(UriCache.find_by(uri:)).to have_attributes(
            status: 'failed', value: nil, permanent: true,
            reason: 'This authority record has been deleted because it is not a valid heading.'
          )
        end
      end

      context 'UT (cache integration)' do
        let(:uri) { 'http://id.loc.gov/authorities/names/n2017180154' }

        before { stub_remote_fetch('loc_ut.nt') }

        it 'caches the resolved label' do
          expect { described_class.lookup(uri) }
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
        described_class.lookup(uri)
        expect(captured_uri).to eq 'http://vocab.getty.edu/aat/300022208'
      end

      it 'resolves to the English label' do
        expect(described_class.lookup(uri)).to eq 'Postmodern'
      end
    end

    context 'from GeoNames' do
      let(:uri) { 'http://sws.geonames.org/4624443' }

      before { stub_remote_fetch('geonames.rdf') }

      it 'resolves to the English label via geonames:name predicate' do
        expect(described_class.lookup(uri)).to eq 'Gatlinburg'
      end

      context 'when the value is a www.geonames.org page' do
        let(:uri) { 'https://www.geonames.org/4624443/gatlinburg.html' }

        it 'fetches the RDF document for the same place' do
          fetched = []
          allow(ActiveTriples::Resource).to receive(:new).and_wrap_original do |method, rdf_uri|
            fetched << rdf_uri.to_s
            resource = method.call(rdf_uri)
            load_fixture('geonames.rdf', into: resource.graph)
            allow(resource).to receive(:fetch).and_return(resource)
            resource
          end

          expect(described_class.lookup(uri)).to eq 'Gatlinburg'
          expect(fetched).to eq ['https://sws.geonames.org/4624443/about.rdf']
        end
      end

      context 'when the value already ends in /about.rdf' do
        let(:uri) { 'http://sws.geonames.org/4624443/about.rdf' }

        it 'fetches the RDF document once, not a doubled path' do
          fetched = []
          allow(ActiveTriples::Resource).to receive(:new).and_wrap_original do |method, rdf_uri|
            fetched << rdf_uri.to_s
            resource = method.call(rdf_uri)
            load_fixture('geonames.rdf', into: resource.graph)
            allow(resource).to receive(:fetch).and_return(resource)
            resource
          end

          expect(described_class.lookup(uri)).to eq 'Gatlinburg'
          expect(fetched).to eq ['http://sws.geonames.org/4624443/about.rdf']
        end
      end
    end

    context 'from Wikidata' do
      context 'example 1 (entity URI)' do
        let(:uri) { 'https://www.wikidata.org/entity/Q85304029' }

        before { stub_remote_fetch('wikidata_1.nt') }

        it 'resolves to the English label' do
          expect(described_class.lookup(uri)).to eq 'Dorothy Doolittle'
        end
      end

      context 'example 2 (redirect in RDF)' do
        let(:uri) { 'http://www.wikidata.org/entity/Q107881652' }

        before { stub_remote_fetch('wikidata_2.nt') }

        it 'resolves to the English label' do
          expect(described_class.lookup(uri)).to eq "Tennessee Volunteers men's tennis"
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
          described_class.lookup(uri)
          expect(captured_uri).to include('/entity/')
          expect(captured_uri).not_to include('/wiki/')
        end

        it 'resolves to the English label' do
          expect(described_class.lookup(uri)).to eq 'Karen Weekly'
        end
      end
    end

    context 'from Homosaurus' do
      let(:uri) { 'https://homosaurus.org/v3/homoit0000070' }

      before { stub_remote_fetch('homosaurus.nt') }

      it 'resolves to the English label' do
        expect(described_class.lookup(uri)).to eq 'LGBTQ+ artists'
      end
    end

    context 'from RightsStatements' do
      let(:uri) { 'http://rightsstatements.org/vocab/InC/1.0/' }

      before { stub_remote_fetch('rights.ttl') }

      it 'resolves the English label' do
        expect(described_class.lookup(uri)).to eq 'In Copyright'
      end
    end

    context 'from Creative Commons' do
      let(:uri) { 'http://creativecommons.org/licenses/by-nc/4.0/' }

      before { stub_remote_fetch('licenses.rdf') }

      it 'resolves the English label' do
        expect(described_class.lookup(uri)).to eq 'Attribution-NonCommercial 4.0 International'
      end
    end

    context 'when the remote fetch fails' do
      let(:uri) { 'http://test.uri/broken' }

      before { stub_fetch_error('connection refused') }

      it 'logs the failure and records a temporary one' do
        expect(Rails.logger).to receive(:warn).with("Failed to load RDF data for #{uri}: connection refused")

        expect(described_class.lookup(uri)).to be_nil
        expect(UriCache.find_by(uri:)).to have_attributes(status: 'failed', permanent: false,
                                                          reason: 'connection refused')
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

      it 'records a permanent failure' do
        expect(described_class.lookup(uri)).to be_nil
        expect(UriCache.find_by(uri:)).to have_attributes(status: 'failed', permanent: true,
                                                          reason: 'No label found')
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
