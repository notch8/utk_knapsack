# frozen_string_literal: true

# OVERRIDE iiif_print 3.2.3: a file set UTK supplied as a ThumbnailImage gets Hyrax's thumbnail only,
# none of the work type's IiifPrint plugins, so it is never OCRed into the work's full text.
module HykuKnapsack
  module PluggableDerivativeServiceDecorator
    def plugins_for(file_set)
      resource = file_set.is_a?(Hyrax::FileMetadata) ? Hyrax.query_service.find_by(id: file_set.file_set_id) : file_set
      return Array(default_plugins) if PcdmUse.thumbnail_image?(resource.try(:rdf_type))

      super
    end
  end
end

IiifPrint::PluggableDerivativeService.prepend(HykuKnapsack::PluggableDerivativeServiceDecorator)
