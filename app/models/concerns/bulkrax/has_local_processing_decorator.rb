# frozen_string_literal: true

module Bulkrax
  module HasLocalProcessingDecorator
    PDF_VIEWER_DEFAULTS = %w[show_pdf_viewer show_pdf_download_button].freeze

    def add_local
      super
      PDF_VIEWER_DEFAULTS.each do |key|
        next unless factory_class&.method_defined?(key)

        parsed_metadata[key] = '1' if parsed_metadata[key].to_s.empty?
      end
    end
  end
end

Bulkrax::HasLocalProcessing.prepend(Bulkrax::HasLocalProcessingDecorator)
