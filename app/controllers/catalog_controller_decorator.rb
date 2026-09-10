# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 to facet creator and contributor from the compound
# properties instead of the flat ones, and to drop the publisher facet.
#
# UTK records agents as `creators` / `contributors` compounds (name + role), so
# the facetable Solr field is the sub-property's derived `<compound>_name_sim`
# rather than `creator_sim` / `contributor_sim`. `publisher_sim` goes with them:
# publisher is a `contributors` role now, so no property writes that field and
# the facet would always render empty.
module CatalogControllerDecorator
  COMPOUND_FACETS = {
    'creator_sim' => ['creators_name_sim', { label: 'Creator', limit: 5 }],
    'contributor_sim' => ['contributors_name_sim', { label: 'Contributor', limit: 5 }],
    'publisher_sim' => nil
  }.freeze

  module_function

  # Blacklight's `facet_fields` is insertion-ordered and the sidebar renders in
  # that order, so each replacement is spliced in where the facet it replaces
  # sat rather than appended to the end.
  def swap_in_compound_facets(config)
    rebuilt = config.facet_fields.each_with_object({}) do |(key, field_config), memo|
      unless COMPOUND_FACETS.key?(key)
        memo[key] = field_config
        next
      end

      name, options = COMPOUND_FACETS[key]
      next if name.blank?

      memo[name] = Blacklight::Configuration::FacetField.new(field: name, **options).normalize!
    end

    config.facet_fields.replace(rebuilt)
  end

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
  CatalogControllerDecorator.swap_in_compound_facets(config)
  CatalogControllerDecorator.add_date_range_facet(config)
  CatalogControllerDecorator.hide_machine_readable_date_facets(config)
  CatalogControllerDecorator.search_machine_readable_dates(config)
  config.add_facet_fields_to_solr_request!
end
