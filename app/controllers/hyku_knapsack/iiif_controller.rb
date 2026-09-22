# frozen_string_literal: true

module HykuKnapsack
  # Inherits ::ApplicationController (not HykuKnapsack::ApplicationController, a blank
  # ActionController::Base shell) for current_ability and the tenant auth_if_needed gate.
  class IiifController < ::ApplicationController
    rescue_from ActionController::BadRequest, with: :render_bad_request

    def show
      raise ActionController::BadRequest, 'Missing X-Origin-URI header' if origin_uri.blank?
      if HykuKnapsack::IiifAuthorizationService.new(self).can?(:show, file_set_id_for(origin_uri))
        render plain: 'success', status: :ok
      else
        render plain: 'unauthorized', status: :unauthorized
      end
    end

    private

    def origin_uri
      request.headers['X-Origin-URI']
    end

    def file_set_id_for(source_uri)
      uri = CGI.unescape(source_uri)
      # If you change this match algorithm you should also change the match algorithm in the deploy templates
      # for the nginx iiif_auth cache, in ops/dev-deploy.tmpl.yaml and ops/staging-deploy.tmpl.yaml
      # currently starts with: map ${DOLLAR}request_uri ${DOLLAR}iiif_auth_fileset_id [...]
      match = uri.match(%r{\A/iiif/2/([\w-]+)/})
      raise ActionController::BadRequest, 'Malformed X-Origin-URI header' if match.nil?

      match[1]
    end

    def render_bad_request(exception)
      Rails.logger.warn("Bad request in IiifController: #{exception.message}")
      render json: { error: 'bad-request' }, status: :bad_request
    end
  end
end
