# frozen_string_literal: true

module HykuKnapsack
  class IiifAuthorizationService
    attr_reader :controller
    def initialize(controller)
      @controller = controller
    end

    # @note we ignore the `action` param here in favor of the `:show` action for all permissions
    def can?(_action, file_set_id)
      controller.current_ability.can?(:show, file_set_id)
    end
  end
end
