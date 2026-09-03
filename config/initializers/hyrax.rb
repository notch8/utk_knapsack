# frozen_string_literal: true

# Use this to override any Hyrax configuration from the Knapsack

# Needs to stay in #after_initialize
# @see https://github.com/notch8/palni_palci_knapsack/commit/e17e7e56
Rails.application.config.after_initialize do
  Hyrax.config do |config|
  # Injected via `rails g hyrax:work_resource StillImage`
  config.register_curation_concern :still_image
  # Injected via `rails g hyrax:work_resource Audio`
  config.register_curation_concern :audio
  # Injected via `rails g hyrax:work_resource Book`
  config.register_curation_concern :book
  # Injected via `rails g hyrax:work_resource CompoundObject`
  config.register_curation_concern :compound_object
  # Injected via `rails g hyrax:work_resource Newspaper`
  config.register_curation_concern :newspaper
  # Injected via `rails g hyrax:work_resource Pdf`
  config.register_curation_concern :pdf
  # Injected via `rails g hyrax:work_resource Video`
  config.register_curation_concern :video
    config.flexible = ActiveModel::Type::Boolean.new.cast(ENV.fetch('HYRAX_FLEXIBLE', 'false'))

    # Prepend to ensure knapsack profile is checked before the host app's profiles.
    config.schema_loader_config_search_paths.unshift(HykuKnapsack::Engine.root) \
      if config.respond_to?(:schema_loader_config_search_paths)
  end
end
