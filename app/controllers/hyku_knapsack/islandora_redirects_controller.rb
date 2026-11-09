# frozen_string_literal: true

module HykuKnapsack
  class IslandoraRedirectsController < ::ApplicationController
    def show
      return redirect_to(main_app.root_path, status: :moved_permanently) if params[:pid] == 'digital:collections'

      doc = record_for(params[:pid])
      return redirect_to(main_app.root_path, alert: t('hyku_knapsack.islandora_redirects.not_found', pid: ERB::Util.html_escape(params[:pid]))) if doc.nil?

      redirect_to path_for(doc), status: :moved_permanently
    end

    private

    def record_for(pid)
      hit = Hyrax::SolrService.query("{!term f=primary_identifier_sim}#{pid}", fq: 'read_access_group_ssim:public', fl: 'id,has_model_ssim', rows: 1).first
      SolrDocument.new(hit) if hit
    end

    def path_for(doc)
      doc.collection? ? hyrax.collection_path(doc) : main_app.polymorphic_path(doc)
    end
  end
end
