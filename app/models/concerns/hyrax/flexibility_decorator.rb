# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0 Hyrax::Flexibility.load to default
# show_pdf_viewer and show_pdf_download_button to true for
# Valkyrie resources, matching ActiveFedora's PdfBehavior.
module Hyrax
  module FlexibilityDecorator
    PDF_VIEWER_DEFAULTS = { show_pdf_viewer: true, show_pdf_download_button: true }.freeze

    def load(attributes, safe = false)
      struct = super
      PDF_VIEWER_DEFAULTS.each do |key, default|
        next unless struct.respond_to?(key) && struct.respond_to?(:set_value)
        struct.set_value(key, default) if struct.send(key).nil?
      end
      struct
    end
  end
end

Hyrax::Flexibility::ClassMethods.prepend(Hyrax::FlexibilityDecorator)
