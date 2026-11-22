# frozen_string_literal: true

module HykuKnapsack
  class ErrorsController < ::ApplicationController
    include Hyku::HomePageThemesBehavior

    def not_found
      render status: :not_found
    end
  end
end
