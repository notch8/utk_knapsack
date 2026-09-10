# frozen_string_literal: true

module CatalogControllerDecorator
  module_function

  def add_date_range_facet(config)
    return if config.facet_fields.key?(UtkDateRangeIndexing::SOLR_FIELD)

    config.add_facet_field UtkDateRangeIndexing::SOLR_FIELD,
                           label: 'Date Created/Issued',
                           range: { assumed_boundaries: [1800, Time.zone.now.year + 2] },
                           include_in_advanced_search: false
  end

  def edtf_properties
    profile = YAML.safe_load_file(Hyrax::Schema.m3_schema_loader.config_paths.first.to_s)

    profile.fetch('properties', {}).select { |_name, prop| prop['syntax'].to_s.casecmp?('edtf') }.keys
  end

  def hide_machine_readable_date_facets(config)
    edtf_properties.each do |itemprop|
      key = "#{itemprop}_sim"
      next if config.facet_fields.key?(key)

      config.add_facet_field key, show: false, include_in_request: false, include_in_advanced_search: false
    end
  end

  def search_machine_readable_dates(config)
    fields = %w[
      date_created_d_tesim
      date_issued_d_tesim
      date_created_tesim
      date_issued_tesim
    ].join(' ')

    config.search_fields['date_created']&.tap do |field|
      field.label = 'Date Created/Issued'
      field.solr_local_parameters = { qf: fields, pf: fields }
    end
  end
end

CatalogController.configure_blacklight do |config|
  CatalogControllerDecorator.add_date_range_facet(config)
  CatalogControllerDecorator.hide_machine_readable_date_facets(config)
  CatalogControllerDecorator.search_machine_readable_dates(config)
end
