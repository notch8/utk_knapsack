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

    it 'include nothing the profile hides from search results' do
      expect(config.index_fields.keys & index_fields_of.call(hidden)).to be_empty
    end

    it 'include every displayed property the profile leaves in search results' do
      expect(config.index_fields.keys).to include(*displayed.map { |key| "#{profile['properties'][key].fetch('name', key)}_tesim" })
    end
  end

  describe 'keyword search' do
    let(:fresh_config) do
      Blacklight::Configuration.new.tap do |blacklight|
        blacklight.add_search_field('all_fields') { |field| field.solr_parameters = { qf: 'title_tesim subject_tesim' } }
      end
    end
    let(:qf) { fresh_config.search_fields['all_fields'].solr_parameters[:qf].split }

    before { CatalogControllerDecorator.search_hidden_properties_by_keyword(fresh_config) }

    it 'searches subject labels, repository, and archival collection though the profile hides them from results' do
      expect(qf).to include('subject_label_tesim', 'repository_tesim', 'archival_collection_tesim')
    end

    it 'keeps the fields it already searched, without repeating them' do
      expect(qf).to eq qf.uniq
      expect(qf).to include('title_tesim', 'subject_tesim')
    end
  end

  describe 'facet limits' do
    let(:fresh_config) do
      Blacklight::Configuration.new.tap do |blacklight|
        blacklight.add_facet_field 'from_the_profile_sim', label: 'From the profile'
        blacklight.add_facet_field 'declared_by_hyku_sim', limit: 3
        blacklight.add_facet_field 'date_range_isim', range: { assumed_boundaries: [1800, 2030] }
      end
    end

    before { CatalogControllerDecorator.limit_unlimited_facets(fresh_config) }

    it 'limits a facet registered with no limit, as Hyrax registers profile facets' do
      expect(fresh_config.facet_fields['from_the_profile_sim'].limit).to eq 5
    end

    it 'leaves a limit the catalog already declares' do
      expect(fresh_config.facet_fields['declared_by_hyku_sim'].limit).to eq 3
    end

    it 'leaves range facets unlimited' do
      expect(fresh_config.facet_fields['date_range_isim'].limit).to be_nil
    end

    it 'runs before every catalog action, after the profile has registered its facets' do
      expect(described_class._process_action_callbacks.map(&:filter)).to include(:limit_unlimited_facets)
    end
  end

  describe 'reloading the decorator, as to_prepare does on every dev reload' do
    it 'does not raise on a duplicate field key' do
      path = HykuKnapsack::Engine.root.join('app', 'controllers', 'catalog_controller_decorator.rb')

      expect { load path.to_s }.not_to raise_error
    end
  end
end
