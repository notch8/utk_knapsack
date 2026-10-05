# frozen_string_literal: true

class AdminControlForm < Hyrax::Forms::AdministrativeSetForm
  check_if_flexible(AdminControl)

  include CollectionAccessFiltering

  class << self
    def model_class
      AdminControl
    end
  end
end
