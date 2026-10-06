# frozen_string_literal: true

class UtkMigrationCharacterizationJob < Hyrax::ApplicationJob
  queue_as Hyrax.config.ingest_queue_name

  def perform(file_metadata_id)
    metadata = Hyrax.custom_queries.find_file_metadata_by(id: ::Valkyrie::ID.new(file_metadata_id))
    file = metadata.file

    Hyrax.config.characterization_service.new(
      metadata:,
      file:,
      parser_mapping: Hydra::Works::Characterization.mapper.merge(file_size: :recorded_size),
      **Hyrax.config.characterization_options
    ).characterize

    saved = Hyrax.persister.save(resource: metadata)
    Hyrax.publisher.publish('file.metadata.updated', metadata: saved, user: ::User.system_user)
    generate_derivatives(saved, file)
  end

  private

  def generate_derivatives(metadata, file)
    return unless metadata.original_file?

    file_set = Hyrax.query_service.find_by(id: metadata.file_set_id)
    return extract_pdf_text(file_set, metadata, file) if file_set.thumbnail
    return unless HykuKnapsack::ThumbnailCandidate.match?(file_set, metadata)

    ValkyrieCreateDerivativesJob.perform_later(file_set.id.to_s, metadata.id.to_s)
  end

  def extract_pdf_text(file_set, metadata, file)
    return unless HykuKnapsack::DerivativeCandidate.pdf?(metadata)
    return unless HykuKnapsack::PdfTextExtractor.needed?(file_set, original: metadata)

    file.rewind
    file.disk_path { |path| HykuKnapsack::PdfTextExtractor.call(file_set:, path:, original: metadata) }
  end
end
