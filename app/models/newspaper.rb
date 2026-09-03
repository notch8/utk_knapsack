# frozen_string_literal: true

# Generated via
#  `rails generate hyku_knapsack:work_resource Newspaper`
class Newspaper < Hyrax::Work
  if Hyrax.config.work_include_metadata?
    include Hyrax::Schema(:core_metadata) unless Hyrax.config.work_default_metadata?
    include Hyrax::Schema(:basic_metadata)
    include Hyrax::Schema(:newspaper)
    include Hyrax::Schema(:with_pdf_viewer)
    include Hyrax::Schema(:with_video_embed)
  end

  include Hyrax::ArResource
  include Hyrax::NestedWorks

  include IiifPrint.model_configuration(
    pdf_split_child_model: self,
    pdf_splitter_service: IiifPrint::TenantConfig::PdfSplitter
  )

  if Hyrax.config.flexible?
    def creator
      OrderAlready::InputOrderSerializer.deserialize(@attributes[:creator])
    end

    def creator=(values)
      set_value(:creator, OrderAlready::InputOrderSerializer.serialize(values))
    end
  else
    prepend OrderAlready.for(:creator)
  end
end
