# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 to facet creator and contributor from the compound
# properties instead of the flat ones, to drop the publisher facet, to leave the
# search result fields to the M3 profile, to keep subject, repository and
# archival collection in keyword search, and to limit profile facets to five values.
#
# UTK records agents as `creators` / `contributors` compounds (name + role), so
# the facetable Solr field is the sub-property's derived `<compound>_name_sim`
# rather than `creator_sim` / `contributor_sim`. `publisher_sim` goes with them:
# publisher is a `contributors` role now, so no property writes that field and
# the facet would always render empty.
module CatalogControllerDecorator
  # OVERRIDE: compound fields don't have a way to be automatically faceted, so we manually swap them in
  COMPOUND_FACETS = {
    'creator_sim' => ['creators_name_sim', { label: 'Creator', limit: 5 }],
    'contributor_sim' => ['contributors_name_sim', { label: 'Contributor', limit: 5 }],
    'publisher_sim' => nil
  }.freeze

  # OVERRIDE: Hyrax adds a property to keyword search only when the profile shows it in search results.
  KEYWORD_SEARCH_FIELDS = %w[
    subject_tesim
    subject_label_tesim
    repository_tesim
    archival_collection_tesim
  ].freeze

  DEFAULT_FACET_LIMIT = 5

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

  # OVERRIDE: Hyrax adds index fields per profile property but never removes the ones Hyku declares
  def leave_index_fields_to_the_profile(config)
    config.index_fields.slice!('all_text_tsimv')
  end

  def search_hidden_properties_by_keyword(config)
    solr_parameters = config.search_fields['all_fields'].solr_parameters
    solr_parameters[:qf] = (solr_parameters[:qf].split | KEYWORD_SEARCH_FIELDS).join(' ')
  end

  # OVERRIDE: Hyrax registers profile facets with no limit, which Blacklight reads as show every value
  def limit_unlimited_facets(config)
    config.facet_fields.each_value do |facet|
      facet.limit = DEFAULT_FACET_LIMIT if facet.limit.nil? && !facet.range
    end
  end
end

CatalogController.configure_blacklight do |config|
  CatalogControllerDecorator.swap_in_compound_facets(config)
  CatalogControllerDecorator.leave_index_fields_to_the_profile(config)
  CatalogControllerDecorator.search_hidden_properties_by_keyword(config)
end

# OVERRIDE: profile facets exist only once the controller is built, so the limit is applied per action
CatalogController.class_eval do
  before_action :limit_unlimited_facets

  private

  def limit_unlimited_facets
    CatalogControllerDecorator.limit_unlimited_facets(blacklight_config)
  end
end
