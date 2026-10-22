# frozen_string_literal: true

# OVERRIDE Hyrax v5.3.0 (d5ee8e6) to give the work, file set, single-use link and collection pages the M3 profile
#   - each request's blacklight_config takes the catalog's profile-driven facet, index and search fields,
#     keeping the controller's other settings, such as the file set search builder
#   - answers the catalog predicates those fields name in `if:`, render_optionally? and Hyku's
#     render_in_tenant?, which hides the index fields an account lists as hidden
#   - links those fields' facet values to the catalog; Blacklight's default resolves against the engine
#     routes and recalls the page's :id, giving /files/:id
# TEMPORARY: delete when samvera/hyrax#7711 is in the pinned Hyrax and samvera/hyku#3444 is in the pinned
#   submodule (refs notch8/utk_knapsack#460, notch8/utk_knapsack#439)
module HykuKnapsack
  module CatalogConfigCopiesDecorator
    PROFILE_DRIVEN_FIELDS = %i[facet_fields index_fields search_fields].freeze

    def blacklight_config
      @blacklight_config ||= super.tap do |config|
        ::CatalogController.load_flexible_schema
        catalog = ::CatalogController.blacklight_config.deep_copy
        PROFILE_DRIVEN_FIELDS.each { |fields| config.public_send("#{fields}=", catalog.public_send(fields)) }
      end
    end

    private

    delegate :render_optionally?, :render_in_tenant?, to: :catalog_field_conditions, private: true

    # Allocated, not built: these predicates read only the current account, and CatalogController.new would
    # load the profile a second time.
    def catalog_field_conditions
      @catalog_field_conditions ||= ::CatalogController.allocate
    end

    def search_action_url(options = {})
      main_app.search_catalog_url(options.except(:controller, :action))
    end
  end
end

if Hyrax.config.flexible?
  # The collections controller itself, not CollectionsControllerBehavior, which the admin set dashboard shares
  [Hyrax::WorksControllerBehavior, Hyrax::CollectionsController, Hyrax::FileSetsController,
   Hyrax::SingleUseLinksViewerController].each do |copier|
    copier.prepend(HykuKnapsack::CatalogConfigCopiesDecorator)
  end
end
