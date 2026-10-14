# frozen_string_literal: true

Rails.application.config.to_prepare do
  Hyrax::ManifestBuilderService.prepend(HykuKnapsack::SinglePageManifest::Builder)
  Hyrax::IiifManifestPresenter.prepend(HykuKnapsack::SinglePageManifest::Presenter)
end
