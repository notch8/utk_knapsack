# frozen_string_literal: true

module Bulkrax
  # File set rows carry a `sha1` pointing at existing bytes rather than a
  # filename, so the stock filename validation has nothing to work with.
  class UtkMigrationCsvFileSetEntry < CsvFileSetEntry
    include UtkMigrationFactory

    def add_metadata_for_model
      validate_presence_of_parent!
    end

    def parent_jobs
      Array(parsed_metadata[related_parents_parsed_mapping]).each do |parent_identifier|
        next if parent_identifier.blank?

        PendingRelationship.create!(child_id: identifier,
                                    parent_id: parent_identifier,
                                    importer_run_id: importerexporter.last_run.id,
                                    order: id)
      end
    end
  end
end
