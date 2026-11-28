# frozen_string_literal: true

# OVERRIDE Hyku v7.2.0 Hyku::ThumbnailPresenter#thumbnail_value_from_document: keeps this tenant's thumbnails relative when indexed under an older cname.
#   Keep: not fixed upstream.
module Hyku
  module ThumbnailPresenterDecorator
    private

    def thumbnail_value_from_document
      value = super
      cname = document['account_cname_tesim']&.first
      return value if value.blank? || HykuKnapsack::IndexedCname.current(cname) == cname

      value.delete_prefix(view_context.request.protocol + cname)
    end
  end
end

Hyku::ThumbnailPresenter.prepend(Hyku::ThumbnailPresenterDecorator)
