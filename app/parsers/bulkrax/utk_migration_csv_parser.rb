# frozen_string_literal: true

module Bulkrax
  class UtkMigrationCsvParser < CsvParser
    def self.export_supported?
      false
    end

    def entry_class
      UtkMigrationCsvEntry
    end

    def file_set_entry_class
      UtkMigrationCsvFileSetEntry
    end
  end
end
