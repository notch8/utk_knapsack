# frozen_string_literal: true

static_pages = ActionDispatch::PublicExceptions.new(Rails.public_path)

Rails.application.config.exceptions_app = lambda do |env|
  request = ActionDispatch::Request.new(env)
  return static_pages.call(env) unless request.path_info == '/404' && request.format&.html?

  request.path_parameters = { controller: 'hyku_knapsack/errors', action: 'not_found' }
  AccountElevator.new(HykuKnapsack::ErrorsController.action(:not_found)).call(env)
rescue StandardError => e
  Rails.logger.error("Themed 404 page failed, serving the static one: #{e.class}: #{e.message}")
  static_pages.call(env)
end
