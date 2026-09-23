# frozen_string_literal: true

class UtkMigrationCharacterizationJob < Hyrax::ApplicationJob
  queue_as Hyrax.config.ingest_queue_name

  def perform(file_metadata_id)
    metadata = Hyrax.custom_queries.find_file_metadata_by(id: ::Valkyrie::ID.new(file_metadata_id))

    Hyrax.config.characterization_service.new(
      metadata:,
      file: metadata.file,
      parser_mapping: Hydra::Works::Characterization.mapper,
      **Hyrax.config.characterization_options
    ).characterize

    saved = Hyrax.persister.save(resource: metadata)
    Hyrax.publisher.publish('file.metadata.updated', metadata: saved, user: ::User.system_user)
  end
end
