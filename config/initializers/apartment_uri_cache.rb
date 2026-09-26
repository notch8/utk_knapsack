# frozen_string_literal: true

if defined?(Apartment)
  Apartment.configure do |config|
    config.excluded_models += %w[UriCache] unless config.excluded_models.include?('UriCache')
  end
end
