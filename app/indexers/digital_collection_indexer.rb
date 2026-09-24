# frozen_string_literal: true

class DigitalCollectionIndexer < Hyrax::Indexers::PcdmCollectionIndexer
  check_if_flexible(DigitalCollection)

  include Hyrax::IndexesThumbnails
  include UtkDateRangeProperties
  include UtkUriLabelIndexing
  include HykuIndexing
end
