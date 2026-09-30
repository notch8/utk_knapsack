# frozen_string_literal: true

class UtkMigrationCharacterizationJob < Hyrax::ApplicationJob
  queue_as Hyrax.config.ingest_queue_name

  def perform(file_metadata_id)
    metadata = Hyrax.custom_queries.find_file_metadata_by(id: ::Valkyrie::ID.new(file_metadata_id))

    Hyrax.config.characterization_service.new(
      metadata:,
      file: metadata.file,
      parser_mapping: Hydra::Works::Characterization.mapper.merge(file_size: :recorded_size),
      **Hyrax.config.characterization_options
    ).characterize

    saved = Hyrax.persister.save(resource: metadata)
    Hyrax.publisher.publish('file.metadata.updated', metadata: saved, user: ::User.system_user)
    generate_thumbnail(saved)
  end

  private

  def generate_thumbnail(metadata)
    return unless metadata.original_file?

    file_set = Hyrax.query_service.find_by(id: metadata.file_set_id)
    return if file_set.thumbnail
    return unless HykuKnapsack::ThumbnailCandidate.match?(file_set, metadata)

    ValkyrieCreateDerivativesJob.perform_later(file_set.id.to_s, metadata.id.to_s)
  end
end
