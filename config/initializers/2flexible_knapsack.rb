# frozen_string_literal: true

ENV['HYRAX_FLEXIBLE'] ||= 'true'

if ActiveModel::Type::Boolean.new.cast(ENV.fetch('HYRAX_FLEXIBLE', 'true'))
  ENV['HYRAX_FLEXIBLE_CLASSES'] = %w[
    AdminSetResource
    CollectionResource
    Hyrax::FileSet
    StillImage
    Audio
    Book
    CompoundObject
    Newspaper
    Pdf
    Video
  ].join(',')
end
