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
  end

  describe 'the search result fields' do
    let(:profile) { YAML.safe_load_file(Hyrax::Schema.m3_schema_loader.config_paths.first.to_s) }
    let(:views) { profile['properties'].transform_values { |property| property['view'].is_a?(Hash) ? property['view'] : {} } }
    let(:hidden) { views.select { |_key, view| view['search_results'] == false }.keys }
    let(:displayed) { views.select { |_key, view| view['html_dl'] && view['search_results'] != false }.keys }
    let(:index_fields_of) { ->(keys) { profile['properties'].values_at(*keys).flat_map { |property| Array(property['indexing']) } } }

    before do
      Hyrax::FlexibleSchema.new(profile:).save(validate: false)
      described_class.load_flexible_schema
    end

    it 'include nothing the profile does not declare, besides the full-text snippets' do
      expect(config.index_fields.keys - ['all_text_tsimv']).to all(be_in(index_fields_of.call(profile['properties'].keys)))
    end

    # Hyrax currently doesn't remove index properties without a restart: `search_results: false`
    # only stops it adding a field, so one an earlier profile version added stays registered.
    xit 'include nothing the profile hides from search results' do
      expect(config.index_fields.keys & index_fields_of.call(hidden)).to be_empty
    end

    it 'include every displayed property the profile leaves in search results' do
      expect(config.index_fields.keys).to include(*displayed.map { |key| "#{profile['properties'][key].fetch('name', key)}_tesim" })
    end
  end

  describe 'reloading the decorator, as to_prepare does on every dev reload' do
    it 'does not raise on a duplicate field key' do
      path = HykuKnapsack::Engine.root.join('app', 'controllers', 'catalog_controller_decorator.rb')

      expect { load path.to_s }.not_to raise_error
    end
  end
end
