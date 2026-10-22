# frozen_string_literal: true

# OVERRIDE browse-everything 1.5.0 - only admins may list or resolve a provider's files, and a
# provider that cannot be listed renders a message in the picker instead of an empty modal
module HykuKnapsack
  module BrowseEverythingControllerDecorator
    PROVIDER_ERRORS = [
      Aws::Errors::ServiceError,
      Aws::Errors::MissingCredentialsError,
      Seahorse::Client::NetworkingError
    ].freeze

    def self.prepended(base)
      base.prepend_before_action :authorize_browse_everything!
    end

    def index
      super
    rescue ActionView::Template::Error => e
      raise unless PROVIDER_ERRORS.any? { |error| e.cause.is_a?(error) }

      logger.warn "Browse Everything could not list #{provider_name}: #{e.cause.class}"
      render 'browse_everything/provider_error', layout: !request.xhr?
    end

    private

    def authorize_browse_everything!
      authenticate_user!
      raise CanCan::AccessDenied unless current_ability.admin?
    end
  end
end

BrowseEverythingController.prepend(HykuKnapsack::BrowseEverythingControllerDecorator)
