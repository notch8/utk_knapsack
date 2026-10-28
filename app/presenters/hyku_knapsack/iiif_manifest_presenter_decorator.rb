# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0: leave a file set UTK supplied as a ThumbnailImage out of the manifest; it is the
# work's thumbnail, not one of its pages.
module HykuKnapsack
  module IiifManifestPresenterDecorator
    def member_presenters
      super.reject { |presenter| PcdmUse.thumbnail_image?(presenter.model['rdf_type_tesim']) }
    end
  end
end

Hyrax::IiifManifestPresenter.prepend(HykuKnapsack::IiifManifestPresenterDecorator)
