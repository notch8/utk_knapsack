# frozen_string_literal: true

# OVERRIDE browse-everything 1.5.0 - a signed link's expiry is sent as an absolute time and the file's size
# is sent with it. The driver sent the lifetime in seconds, which BrowseEverything::Retriever parses as a
# date and fails every download on, and no size, which Bulkrax waits to match before an import runs.
module HykuKnapsack
  module BrowseEverythingS3DriverDecorator
    def link_for(path)
      url, extras = super
      extras[:expires] = (Time.current + extras[:expires].to_i).iso8601 if extras.key?(:expires)
      extras[:file_size] = bucket.object(full_path(path)).content_length
      [url, extras]
    end
  end
end

BrowseEverything::Driver::S3.prepend(HykuKnapsack::BrowseEverythingS3DriverDecorator)
