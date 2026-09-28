# frozen_string_literal: true

module HykuKnapsack
  class UriLookupFailuresController < ::ApplicationController
    PER_PAGE = 50
    CITED_WORKS_SHOWN = 5
    WORK_FIELDS = 'id,title_tesim,has_model_ssim'

    with_themed_layout 'dashboard'
    before_action -> { authorize! :manage, :controlled_vocabularies }

    def index
      report = Utk::UriLookupFailureReport.new

      respond_to do |format|
        format.html do
          @rows = Kaminari.paginate_array(report.rows).page(params[:page]).per(PER_PAGE)
          @works = cited_works(@rows)
          add_breadcrumbs
        end
        format.csv { send_data report.to_csv, filename: 'uri_lookup_failures.csv', type: :csv }
      end
    end

    private

    def cited_works(rows)
      ids = rows.flat_map { |row| row.work_ids.first(CITED_WORKS_SHOWN) }.uniq
      return {} if ids.empty?

      docs = Hyrax::SolrService.post("{!terms f=id}#{ids.join(',')}", rows: ids.size, fl: WORK_FIELDS).dig('response', 'docs')
      docs.to_h { |doc| [doc['id'], SolrDocument.new(doc)] }
    end

    def add_breadcrumbs
      add_breadcrumb t(:'hyrax.controls.home'), main_app.root_path
      add_breadcrumb t(:'hyrax.dashboard.breadcrumbs.admin'), hyrax.dashboard_path
      add_breadcrumb t('hyku.admin.controlled_vocabularies'), main_app.controlled_vocabularies_path
      add_breadcrumb t('hyku_knapsack.uri_lookup_failures.title'), hyku_knapsack.uri_lookup_failures_path
    end
  end
end
