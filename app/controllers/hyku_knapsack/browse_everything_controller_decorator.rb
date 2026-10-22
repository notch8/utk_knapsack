# frozen_string_literal: true

# OVERRIDE browse-everything 1.5.0 - only admins may list or resolve a provider's files
module HykuKnapsack
  module BrowseEverythingControllerDecorator
    def self.prepended(base)
      base.prepend_before_action :authorize_browse_everything!
    end

    private

    def authorize_browse_everything!
      authenticate_user!
      raise CanCan::AccessDenied unless current_ability.admin?
    end
  end
end

BrowseEverythingController.prepend(HykuKnapsack::BrowseEverythingControllerDecorator)
