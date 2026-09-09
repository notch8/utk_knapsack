# frozen_string_literal: true

class DigitalCollectionForm < Hyrax::Forms::PcdmCollectionForm
  if Hyrax.config.collection_include_metadata?
    include Hyrax::FormFields(:basic_metadata)
    include Hyrax::FormFields(:bulkrax_metadata)
    include Hyrax::FormFields(:collection_resource)
  end
  check_if_flexible(DigitalCollection)

  include CollectionAccessFiltering

  unless Hyrax.config.collection_flexible?
    property :hide_from_catalog_search, type: Dry::Types['params.bool'], default: false if DigitalCollection.new.respond_to?(:hide_from_catalog_search)
  end

  class << self
    def model_class
      DigitalCollection
    end
  end
end
