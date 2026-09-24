# frozen_string_literal: true

module Hyrax
  class BookIiifManifestPresenter < IiifManifestPresenter
    include Hyrax::AttributesHelper

    def file_set_presenters(...)
      super.each { |presenter| presenter.item_metadata = file_set_metadata(presenter.model) }
    end

    private

    def file_set_metadata(doc)
      file_set_view_definitions(doc).filter_map do |field, options|
        next unless field_visible?(options, self)

        values = file_set_values(doc, field)
        next if values.empty?

        { 'label' => { I18n.locale.to_s => [file_set_label(field, options)] }, 'value' => { 'none' => values } }
      end
    end

    def file_set_view_definitions(doc)
      @file_set_view_definitions ||= {}
      @file_set_view_definitions[[doc.schema_version, doc.contexts]] ||=
        Hyrax::Schema.m3_schema_loader.view_definitions_for(schema: 'Hyrax::FileSet', version: doc.schema_version, contexts: doc.contexts)
    end

    def current_user
      nil
    end

    def file_set_values(doc, field)
      Array(doc["#{field}_tesim"] || doc["#{field}_dtsi"]&.to_date&.to_formatted_s(:standard))
        .map { |value| Loofah.fragment(value.to_s).scrub!(:whitewash).to_s }
        .compact_blank
    end

    def file_set_label(field, options)
      labels = options['display_label'] || {}
      key = labels[I18n.locale.to_s] || labels['default'] || field.to_s.humanize
      I18n.t(key, default: key)
    end
  end
end
