# frozen_string_literal: true

Hyrax::Forms::AdministrativeSetForm.include CollectionAccessFiltering
class AdminControlForm < Hyrax::Forms::AdministrativeSetForm
  check_if_flexible(AdminControl)

  class << self
    def model_class
      AdminControl
    end
  end
end
