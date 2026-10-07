# frozen_string_literal: true

module HykuKnapsack
  class ExtractPdfTextJob < Hyrax::ApplicationJob
    queue_as Hyrax.config.ingest_queue_name

    def perform(file_metadata_id)
      original = Hyrax.custom_queries.find_file_metadata_by(id: ::Valkyrie::ID.new(file_metadata_id))
      file_set = Hyrax.query_service.find_by(id: original.file_set_id)
      return unless PdfTextExtractor.needed?(file_set, original:)

      original.file.disk_path { |path| PdfTextExtractor.call(file_set:, path:, original:) }
    end
  end
end
