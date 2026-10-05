# frozen_string_literal: true

# OVERRIDE Hyrax: look up a flexible record's view definitions under the
# class Valkyrie resolves from has_model_ssim. Hyrax takes the schema name from
# model_name.klass, and with VALKYRIE_TRANSITION off SolrDocument#hydra_model
# skips the resolver, so a file set's "FileSet" becomes the ActiveFedora
# FileSet, a name the profile has no schema for, and the loader falls back to
# title only. Remove once the Hyrax pin includes samvera/hyrax#7677.
module Hyrax
  module AttributesHelperDecorator
    def view_options_for(presenter)
      return super unless presenter.respond_to?(:flexible?) && presenter.flexible?

      document = presenter.solr_document
      Hyrax::Schema.m3_schema_loader.view_definitions_for(schema: flexible_schema_name(presenter),
                                                          version: document.schema_version,
                                                          contexts: document.contexts)
    end

    private

    def flexible_schema_name(presenter)
      Valkyrie.config.resource_class_resolver.call(presenter.solr_document.hydra_model_name).to_s
    rescue NameError
      presenter.model.model_name.klass.to_s
    end
  end
end

Hyrax::AttributesHelper.prepend(Hyrax::AttributesHelperDecorator)
