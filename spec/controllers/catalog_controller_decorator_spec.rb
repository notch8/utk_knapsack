# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CatalogController do
  let(:config) { described_class.blacklight_config }
  let(:facet) { config.facet_fields[DateRangeIndexing::SOLR_FIELD] }

  describe 'the date range facet' do
    it 'is configured on the field the indexers write' do
      expect(facet).to be_present
    end

    it 'is labeled for both senses of date' do
      expect(facet.display_label('facet')).to eq 'Date Created/Issued'
    end

    it 'sends the facets the knapsack adds to Solr, though they are added after Hyku calls add_facet_fields_to_solr_request!' do
      expect(config.add_facet_fields_to_solr_request).to be true
    end
  end

  describe 'the machine-readable date facets' do
    it 'derives the properties from the profile rather than a hand-kept list' do
      expect(CatalogControllerDecorator.edtf_properties)
        .to include('date_created_d', 'date_issued_d')
    end

    # Compared exactly: Hyku's own profile lives at `<knapsack root>/hyrax-webapp
    # /config/metadata_profiles/m3_profile.yaml`, so a prefix match passes even
    # when Hyrax resolves Hyku's file. That file declares no `syntax:` key at
    # all, so a silent flip to it would make edtf_properties return [] and hide
    # nothing.
    it 'reads them from the knapsack profile, not Hyku\'s' do
      expect(Hyrax::Schema.m3_schema_loader.config_paths.first.to_s)
        .to eq HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'm3_profile.yaml').to_s
    end

    # Hyrax re-adds a facet per `facetable` property on every request, so this is
    # the guard against a newly facetable EDTF property putting raw EDTF values
    # (`1948~/1952`, and the `[]` sentinel) back in the sidebar.
    it 'leaves no machine-readable date facet renderable' do
      described_class.load_flexible_schema

      renderable = config.facet_fields.select { |key, facet| key.end_with?('_d_sim') && facet.if != false }

      expect(renderable.keys).to be_empty
    end

    it 'keeps the range facet renderable alongside them' do
      described_class.load_flexible_schema

      expect(config.facet_fields[DateRangeIndexing::SOLR_FIELD].if).not_to be false
    end
  end

  describe 'the date search field' do
    let(:field) { config.search_fields['date_created'] }

    it 'searches the machine-readable dates' do
      expect(field.solr_local_parameters[:qf]).to include 'date_created_d_tesim', 'date_issued_d_tesim'
    end

    it 'still searches the human-readable dates' do
      expect(field.solr_local_parameters[:qf]).to include 'date_created_tesim', 'date_issued_tesim'
    end

    it 'boosts the same fields it queries' do
      expect(field.solr_local_parameters[:pf]).to eq field.solr_local_parameters[:qf]
    end

    it 'keeps the numeric range field out of qf, where it can never match a term' do
      expect(field.solr_local_parameters[:qf]).not_to include DateRangeIndexing::SOLR_FIELD
    end

    it 'is labeled for both senses of date' do
      expect(field.label).to eq 'Date Created/Issued'
    end
  end

  describe 'reloading the decorator, as to_prepare does on every dev reload' do
    it 'does not raise on a duplicate field key' do
      path = HykuKnapsack::Engine.root.join('app', 'controllers', 'catalog_controller_decorator.rb')

      expect { load path.to_s }.not_to raise_error
    end
  end
end
