# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/NestedGroups
RSpec.describe UriLabelResolver do
  let(:graph) { RDF::Graph.new }

  def load_fixture(filename, format: nil)
    format ||= case File.extname(filename)
               when '.nt' then :ntriples
               when '.rdf' then :rdfxml
               when '.ttl' then :ttl
               end

    File.open(Rails.root.join('..', 'spec', 'fixtures', 'rdf_data', filename)) do |file|
      RDF::Reader.for(format).new(file) { |reader| reader.each_statement { |s| graph << s } }
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
      before do
        resource = instance_double(ActiveTriples::Resource)
        allow(ActiveTriples::Resource).to receive(:new).and_return(resource)
        allow(resource).to receive(:fetch).and_return(resource)
        allow(resource).to receive(:rdf_label).and_return([label])
        allow(resource).to receive(:graph).and_return(graph)
      end

      context 'example 1' do
        let(:uri) { 'https://id.loc.gov/authorities/names/n79007751' }
        let(:label) { 'New York (N.Y.)' }

        it 'resolves the label' do
          expect(described_class.label_for(uri)).to eq 'New York (N.Y.)'
        end
      end

      context 'example 2' do
        let(:uri) { 'http://id.loc.gov/authorities/subjects/sj96006364' }
        let(:label) { 'Water power' }

        it 'resolves the label' do
          expect(described_class.label_for(uri)).to eq 'Water power'
        end
      end

      context 'example 3 (has .html in uri)' do
        let(:uri) { 'https://id.loc.gov/authorities/subjects/sh85088046.html' }
        let(:label) { 'Motion picture film collections' }

        it 'resolves the label' do
          expect(described_class.label_for(uri)).to eq 'Motion picture film collections'
        end
      end
    end

    context 'from the Getty' do
      let(:uri) { 'http://vocab.getty.edu/page/aat/300022208' }

      before do
        resource = instance_double(ActiveTriples::Resource)
        allow(ActiveTriples::Resource).to receive(:new).and_return(resource)
        allow(resource).to receive(:fetch).and_return(resource)
        allow(resource).to receive(:rdf_label).and_return(['Postmodern'])
        allow(resource).to receive(:graph).and_return(graph)
      end

      it 'resolves the label' do
        expect(described_class.label_for(uri)).to eq 'Postmodern'
      end
    end

    context 'from Geonames' do
      let(:uri) { 'http://sws.geonames.org/4624443' }

      before do
        load_fixture('geonames.rdf')
        resource = instance_double(ActiveTriples::Resource)
        allow(ActiveTriples::Resource).to receive(:new).and_return(resource)
        allow(resource).to receive(:fetch).and_return(resource)
        allow(resource).to receive(:graph).and_return(graph)
      end

      it 'resolves the label via geonames:name predicate' do
        expect(described_class.label_for(uri)).to eq 'Gatlinburg'
      end
    end

    context 'from Wikidata' do
      before do
        resource = instance_double(ActiveTriples::Resource)
        allow(ActiveTriples::Resource).to receive(:new).and_return(resource)
        allow(resource).to receive(:fetch).and_return(resource)
        allow(resource).to receive(:rdf_label).and_return([label])
        allow(resource).to receive(:graph).and_return(graph)
      end

      context 'example 1' do
        let(:uri) { 'https://www.wikidata.org/entity/Q85304029' }
        let(:label) { 'Dorothy Doolittle' }

        it 'appends .nt and resolves' do
          expect(ActiveTriples::Resource).to receive(:new)
            .with(RDF::URI('https://www.wikidata.org/entity/Q85304029.nt'))
          described_class.label_for(uri)
        end

        it 'resolves the label' do
          expect(described_class.label_for(uri)).to eq 'Dorothy Doolittle'
        end
      end

      context 'example 2 (has redirect)' do
        let(:uri) { 'http://www.wikidata.org/entity/Q107881652' }
        let(:label) { "Tennessee Volunteers men's tennis" }

        it 'resolves the label' do
          expect(described_class.label_for(uri)).to eq "Tennessee Volunteers men's tennis"
        end
      end

      context 'example 3 (using "wiki" instead of "entity")' do
        let(:uri) { 'https://www.wikidata.org/wiki/Q61779863' }
        let(:label) { 'Karen Weekly' }

        it 'rewrites /wiki/ to /entity/ and appends .nt' do
          expect(ActiveTriples::Resource).to receive(:new)
            .with(RDF::URI('https://www.wikidata.org/entity/Q61779863.nt'))
          described_class.label_for(uri)
        end
      end
    end

    context 'from Homosaurus' do
      let(:uri) { 'https://homosaurus.org/v3/homoit0000070' }

      before do
        resource = instance_double(ActiveTriples::Resource)
        allow(ActiveTriples::Resource).to receive(:new)
          .with(RDF::URI('https://homosaurus.org/v3/homoit0000070.nt'))
          .and_return(resource)
        allow(resource).to receive(:fetch).and_return(resource)
        allow(resource).to receive(:rdf_label).and_return(['LGBTQ+ artists'])
        allow(resource).to receive(:graph).and_return(graph)
      end

      it 'resolves the label' do
        expect(described_class.label_for(uri)).to eq 'LGBTQ+ artists'
      end
    end

    context 'from RightsStatements (local QA)' do
      let(:uri) { 'http://rightsstatements.org/vocab/InC/1.0/' }

      before do
        authority = instance_double(Qa::Authorities::Local::FileBasedAuthority)
        allow(Qa::Authorities::Local).to receive(:subauthority_for)
          .with('rights_statements').and_return(authority)
        allow(authority).to receive(:find).with(uri).and_return('term' => 'In Copyright')
      end

      it 'resolves from local QA authority' do
        expect(described_class.label_for(uri)).to eq 'In Copyright'
      end
    end

    context 'from Creative Commons (local QA)' do
      let(:uri) { 'http://creativecommons.org/licenses/by-nc/4.0/' }

      before do
        authority = instance_double(Qa::Authorities::Local::FileBasedAuthority)
        allow(Qa::Authorities::Local).to receive(:subauthority_for)
          .with('licenses').and_return(authority)
        allow(authority).to receive(:find).with(uri)
                                          .and_return('term' => 'Attribution-NonCommercial 4.0 International')
      end

      it 'resolves from local QA authority' do
        expect(described_class.label_for(uri)).to eq 'Attribution-NonCommercial 4.0 International'
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
        resource = instance_double(ActiveTriples::Resource)
        allow(ActiveTriples::Resource).to receive(:new).and_return(resource)
        allow(resource).to receive(:fetch).and_return(resource)
        allow(resource).to receive(:rdf_label).and_return([])
        allow(resource).to receive(:graph).and_return(graph)
      end

      it 'returns the URI with a no-label annotation' do
        expect(described_class.label_for(uri)).to eq 'http://example.com/no-label (No label found)'
      end
    end

    context 'UriCache integration' do
      let(:uri) { 'http://id.loc.gov/authorities/names/n2017180154' }

      before do
        allow(UriCache).to receive(:find_by).and_call_original
        allow(UriCache).to receive(:create!).and_call_original
      end

      context 'when the URI is cached' do
        before { create(:uri_cache) }

        it 'returns the cached value without fetching' do
          expect(ActiveTriples::Resource).not_to receive(:new)
          expect(described_class.label_for(uri)).to eq 'University of Tennessee'
        end
      end

      context 'when the URI is not cached' do
        before do
          resource = instance_double(ActiveTriples::Resource)
          allow(ActiveTriples::Resource).to receive(:new).and_return(resource)
          allow(resource).to receive(:fetch).and_return(resource)
          allow(resource).to receive(:rdf_label).and_return(['University of Tennessee'])
          allow(resource).to receive(:graph).and_return(graph)
        end

        it 'caches the resolved label' do
          expect { described_class.label_for(uri) }
            .to change { UriCache.where(uri:).count }.from(0).to(1)
          expect(UriCache.find_by(uri:).value).to eq 'University of Tennessee'
        end
      end
    end
  end
end
# rubocop:enable RSpec/NestedGroups
