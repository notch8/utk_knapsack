# frozen_string_literal: true

# OVERRIDE Hyrax 5.x - serve a file set's thumbnail to anyone who can read its work
module HykuKnapsack
  module DownloadsControllerDecorator
    private

    def authorize_download!
      return if thumbnail_request? && work_readable?

      super
    end

    def thumbnail_request?
      params[:file] == 'thumbnail' && !params.key?(:mime_type)
    end

    def work_readable?
      work = file_set_parent(params[asset_param_key])
      work.present? &&
        current_ability.can?(:read, work.id.to_s) &&
        !workflow_restriction?(work, ability: current_ability)
    rescue Valkyrie::Persistence::ObjectNotFoundError, Hyrax::ObjectNotFoundError
      false
    end
  end
end

Hyrax::DownloadsController.prepend(HykuKnapsack::DownloadsControllerDecorator)
