# frozen_string_literal: true

# Generated via
#  `rails generate hyku_knapsack:work_resource StillImage`
class StillImage < Hyrax::Work
  include Hyrax::ArResource
  include Hyrax::NestedWorks

  include IiifPrint.model_configuration(
    pdf_split_child_model: self,
    pdf_splitter_service: IiifPrint::TenantConfig::PdfSplitter
  )

  def creator
    OrderAlready::InputOrderSerializer.deserialize(@attributes[:creator])
  end

  def creator=(values)
    set_value(:creator, OrderAlready::InputOrderSerializer.serialize(values))
  end
end
