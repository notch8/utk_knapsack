# frozen_string_literal: true

# OVERRIDE Hyku v7.2.0 Hyku::ThumbnailPresenter#thumbnail_value_from_document: keeps this tenant's thumbnails relative when indexed under an older cname.
#   Keep: not fixed upstream.
module Hyku
  module ThumbnailPresenterDecorator
    private

    def thumbnail_value_from_document
      value = super
      uri = URI.parse(value.to_s)
      return value if uri.host.blank? || HykuKnapsack::IndexedCname.current(uri.host) == uri.host

      uri.request_uri
    rescue URI::InvalidURIError
      value
    end
  end
end

Hyku::ThumbnailPresenter.prepend(Hyku::ThumbnailPresenterDecorator)
