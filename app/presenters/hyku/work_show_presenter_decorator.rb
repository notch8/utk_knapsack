# frozen_string_literal: true

# OVERRIDE Hyku 7.1.0 WorkShowPresenter#show_pdf_viewer,
# #show_pdf_download_button, #authorized_member_models
module Hyku
  module WorkShowPresenterDecorator
    def show_pdf_viewer
      super.presence || true
    end

    def show_pdf_download_button
      super.presence || true
    end

    def authorized_member_models
      ids = authorized_item_ids
      return {} if ids.empty?

      Hyrax::SolrService.post("{!terms f=id}#{ids.join(',')}", rows: ids.size, fl: 'id,has_model_ssim')
                        .dig('response', 'docs')
                        .to_a
                        .to_h { |doc| [doc['id'], Array(doc['has_model_ssim']).first.to_s] }
    end
  end
end

Hyku::WorkShowPresenter.prepend(Hyku::WorkShowPresenterDecorator)
