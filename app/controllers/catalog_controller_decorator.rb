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

  # Blacklight's `facet_fields` is insertion-ordered and the sidebar renders in
  # that order, so each replacement is spliced in where the facet it replaces
  # sat rather than appended to the end.
  def self.swap_in_compound_facets(config)
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
end

CatalogController.configure_blacklight do |config|
  CatalogControllerDecorator.swap_in_compound_facets(config)
  config.add_facet_fields_to_solr_request!
end
