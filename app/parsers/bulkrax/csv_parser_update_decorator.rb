# frozen_string_literal: true

# OVERRIDE Bulkrax 9.5.1: stop requiring a title column across the whole CSV,
# so a sheet that only updates existing records can leave it out. Each row
# that creates a record is still checked for a title by CsvEntry#validate_record.
module Bulkrax
  module CsvParserUpdateDecorator
    def valid_import?
      file_paths.is_a?(Array)
    rescue StandardError => e
      set_status_info(e)
      false
    end
  end
end

Bulkrax::CsvParser.prepend(Bulkrax::CsvParserUpdateDecorator)
