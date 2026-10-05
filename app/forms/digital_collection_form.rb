# frozen_string_literal: true

class DigitalCollectionForm < Hyrax::Forms::PcdmCollectionForm
  check_if_flexible(DigitalCollection)

  include CollectionAccessFiltering

  class << self
    def model_class
      DigitalCollection
    end
  end
end
