# frozen_string_literal: true

module UtkDateRangeProperties
  extend ActiveSupport::Concern

  class_methods do
    def edtf_date_properties
      %i[date_created_d date_issued_d]
    end
  end
end
