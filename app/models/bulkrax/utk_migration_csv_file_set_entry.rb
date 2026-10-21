# frozen_string_literal: true

module Bulkrax
  # File set rows carry a `sha1` pointing at existing bytes rather than a
  # filename, so the stock filename validation has nothing to work with.
  class UtkMigrationCsvFileSetEntry < CsvFileSetEntry
    include UtkMigrationFactory

    def add_metadata_for_model
      validate_presence_of_parent!
    end
  end
end
