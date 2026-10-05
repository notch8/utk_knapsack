# frozen_string_literal: true

# OVERRIDE iiif_print: builds IIIF URLs from the requesting tenant's own host instead of one static external_iiif_url (this app is multitenant).
module IiifPrint
  module ExternalIiifDisplayImagePresenterDecorator
    def display_image_url(base_url = nil)
      url_builder = Hyrax.config.iiif_image_url_builder
      args = [latest_file_id, tenant_iiif_base_url(base_url), Hyrax.config.iiif_image_size_default]
      args << image_format(alpha_channels) if url_builder.arity == 4
      url_builder.call(*args).gsub(%r{images/}, '')
    end

    def iiif_endpoint(_file_id = nil, base_url: nil)
      IIIFManifest::IIIFEndpoint.new(
        File.join(tenant_iiif_base_url(base_url), latest_file_id),
        profile: Hyrax.config.iiif_image_compliance_level_uri
      )
    end

    private

    # base_url may arrive scheme-less (e.g. request.host) -- add https:// or UV silently
    # mis-resolves the manifest service @id as relative to its own /uv/ mount.
    def tenant_iiif_base_url(base_url)
      host = (base_url || base_url_for_iiif).to_s
      host = "https://#{host}" unless host.match?(%r{\Ahttps?://})
      "#{host}/iiif/2"
    end
  end
end

# HykuKnapsack::Engine force-loads this file (any app/**/*_decorator*.rb) during
# to_prepare, which can run before Zeitwerk has autoloaded IiifPrint::Engine's own
# (isolated-namespace) classes -- require the target file directly instead of
# relying on autoloading to resolve it in time.
require File.join(IiifPrint::GEM_PATH, 'app/presenters/iiif_print/external_iiif_display_image_presenter')

IiifPrint::ExternalIiifDisplayImagePresenter.prepend(IiifPrint::ExternalIiifDisplayImagePresenterDecorator)
