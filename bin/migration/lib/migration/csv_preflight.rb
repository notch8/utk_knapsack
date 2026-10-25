# frozen_string_literal: true

module Migration
  class CsvPreflight < Preflight
    def initialize(rows, headers)
      super(rows, headers, looked_up: false)
    end

    def stops
      [duplicate_stop, role_column_stop, rdf_type_stop, remote_files_stop, required_stop, unknown_stop, vocabulary_stop].compact.flatten
    end

    private

    def duplicate_stop
      duplicates = @rows.map { |row| row['source_identifier'] }.tally.select { |_, n| n > 1 }.keys
      "DUPLICATE ROWS: #{duplicates.size} #{duplicates.first(5).inspect}" if duplicates.any?
    end

    def role_column_stop
      columns = @headers.select { |header| Profile::ROLE_FOR_COLUMN.key?(header) }
      "ROLE COLUMNS need <compound>_name_N and <compound>_role_N: #{columns.join(', ')}" if columns.any?
    end

    def rdf_type_stop
      rows = @rows.select { |row| row['rdf_type'].to_s.include?('https://pcdm.org') }
      "HTTPS RDF_TYPE: #{rows.size} rows use https://pcdm.org #{ids(rows)}" if rows.any?
    end

    def remote_files_stop
      rows = @rows.select { |row| row['model'] == 'FileSet' && row['remote_files'].to_s.strip.empty? }
      "NO REMOTE FILE: #{rows.size} file sets #{ids(rows)}" if rows.any?
    end

    def ids(rows)
      rows.first(5).map { |row| row['source_identifier'] }.inspect
    end
  end
end
