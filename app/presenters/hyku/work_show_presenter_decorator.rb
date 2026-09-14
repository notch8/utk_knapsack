# frozen_string_literal: true

# OVERRIDE Hyku (submodule) to pass the query positionally so
# Hyrax::SolrService.post merges in qt=standard - passing it as `q:` silently
# skips that merge, which Solr 9 needs for {!join} queries to resolve correctly.
module Hyku
  module WorkShowPresenterDecorator
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
