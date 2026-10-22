# frozen_string_literal: true

# OVERRIDE Hyrax v5.3.0 (d5ee8e6) to give the work, file set, single-use link and collection pages the M3 profile
#   - each request's blacklight_config takes the catalog's profile-driven facet, index and search fields,
#     keeping the controller's other settings, such as the file set search builder
# TEMPORARY: delete when samvera/hyrax#7711 is in the pinned Hyrax (refs notch8/utk_knapsack#460)
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
  end
end

if Hyrax.config.flexible?
  # The collections controller itself, not CollectionsControllerBehavior, which the admin set dashboard shares
  [Hyrax::WorksControllerBehavior, Hyrax::CollectionsController, Hyrax::FileSetsController,
   Hyrax::SingleUseLinksViewerController].each do |copier|
    copier.prepend(HykuKnapsack::CatalogConfigCopiesDecorator)
  end
end
