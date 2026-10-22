# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'The catalog config of work, file set and collection pages' do
  let(:profile) { YAML.safe_load_file(Hyrax::Schema.m3_schema_loader.config_paths.first.to_s) }

  before { Hyrax::FlexibleSchema.new(profile:).save(validate: false) }

  context 'when the controller copied it before the catalog served any request' do
    around do |example|
      catalog = CatalogController.blacklight_config
      loaded = { facet_fields: catalog.facet_fields.dup, index_fields: catalog.index_fields.dup, search_fields: catalog.search_fields.dup }
      catalog.facet_fields.delete_if { |key, _facet| key.end_with?('_label_sim') }
      example.run
    ensure
      loaded.each { |fields, saved| catalog.public_send(fields).replace(saved) }
    end

    [Hyrax::VideosController, Hyrax::FileSetsController, Hyrax::CollectionsController,
     Hyrax::SingleUseLinksViewerController].each do |controller_class|
      describe controller_class do
        let(:page) { controller_class.new }
        let(:config) { page.blacklight_config }
        let(:copied_at_boot) do
          controller_class.blacklight_config.deep_copy.tap do |copy|
            copy.facet_fields.delete_if { |key, _facet| key.end_with?('_label_sim') }
            copy.index_fields.slice!('all_text_tsimv')
          end
        end

        before do
          stale = copied_at_boot
          allow(controller_class).to receive(:blacklight_config).and_return(stale)
        end

        it 'facets a controlled property, resource type, on its labels' do
          expect(config.facet_fields).to include('resource_type_label_sim')
        end

        it 'facets an uncontrolled property, temporal, on its stored values' do
          expect(config.facet_fields).to include('temporal_sim')
          expect(config.facet_fields).not_to include('temporal_label_sim')
        end

        it 'has the same search result fields as the catalog' do
          CatalogController.load_flexible_schema

          expect(config.index_fields.keys).to include('title_tesim')
          expect(config.index_fields.keys).to eq CatalogController.blacklight_config.index_fields.keys
        end

        it 'answers each display condition the catalog fields name, such as render_optionally?' do
          CatalogController.load_flexible_schema
          fields = [config.facet_fields, config.index_fields, config.search_fields].flat_map(&:values)
          conditions = fields.flat_map { |field| [field.if, field.unless] }.grep(Symbol).uniq

          expect(conditions).to include(:render_optionally?)
          conditions.each { |condition| expect(page.method(condition).call(fields.first, SolrDocument.new)).to be true }
        end
      end
    end
  end

  it 'leaves the admin set dashboard on the config it copied' do
    copied = Blacklight::Configuration.new
    allow(Hyrax::Admin::AdminSetsController).to receive(:blacklight_config).and_return(copied)

    expect(Hyrax::Admin::AdminSetsController.new.blacklight_config.facet_fields).to be_empty
  end

  it "keeps the file set controller's own search builder" do
    expect(Hyrax::FileSetsController.new.blacklight_config.search_builder_class).to eq Hyrax::FileSetSearchBuilder
  end
end
