# frozen_string_literal: true

# OVERRIDE Hyrax v5.3.0 to carry the whole query string, not only locale, across a redirect 301
module HykuKnapsack
  module RedirectQueryStringDecorator
    private

    def with_locale(path)
      # OVERRIDE: start from the visitor's query params instead of locale alone
      query = request.query_parameters
      query = query.merge('locale' => params[:locale]) if params[:locale].present?
      return path if query.blank?
      separator = path.include?('?') ? '&' : '?'
      "#{path}#{separator}#{Rack::Utils.build_nested_query(query)}"
    end
  end
end

Hyrax::RedirectToDisplayUrl.prepend(HykuKnapsack::RedirectQueryStringDecorator)
Hyrax::RedirectsController.prepend(HykuKnapsack::RedirectQueryStringDecorator)
