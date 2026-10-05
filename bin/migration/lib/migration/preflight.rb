# frozen_string_literal: true

module Migration
  class Preflight
    def initialize(rows, headers, looked_up: true)
      @rows = rows
      @headers = headers
      @looked_up = looked_up
    end

    def stops
      [unmatched_stop, required_stop, digest_stop, unknown_stop, vocabulary_stop].compact.flatten
    end

    private

    def unmatched_stop
      return unless @looked_up

      unmatched = @rows.select { |row| row['id'].nil? }.map { |row| row['source_identifier'] }
      "unmatched source_identifiers: #{unmatched.size} #{unmatched.first(5).inspect}" if unmatched.any?
    end

    def required_stop
      missing = @rows.flat_map { |row| Profile.missing_required(row) }
      rows_affected = missing.map { |m| m.split(' (').first }.uniq.size
      ["MISSING REQUIRED: #{missing.size} across #{rows_affected} rows"] + missing.first(20).map { |m| "  #{m}" } if missing.any?
    end

    def digest_stop
      without = @rows.select { |row| row['model'] == 'FileSet' && row['sha1'].to_s.empty? }
      return if without.empty?

      labels = without.map { |row| row['original_filename'].to_s.empty? ? '(none)' : row['original_filename'] }.tally
      objects = labels.fetch('OBJ', 0)
      file_sets = @rows.count { |row| row['model'] == 'FileSet' }
      ["NO DIGEST: #{without.size} of #{file_sets} file sets cannot be created",
       *labels.sort_by { |_, n| -n }.map { |label, n| "  #{label}: #{n}" },
       ("  #{objects} are OBJ, so that many works arrive with no preservation master" if objects.positive?)].compact
    end

    def unknown_stop
      unknown = @headers.select { |header| Profile.unknown_column?(header) }
      "UNKNOWN ROLE COLUMNS: #{unknown.join(', ')}" if unknown.any?
    end

    def vocabulary_stop
      off = Profile.off_vocabulary(@rows)
      return if off.empty?

      values = off.sum { |_, by_value| by_value.size }
      ["OFF VOCABULARY: #{values} #{values == 1 ? 'value' : 'values'} not in their vocabulary; correct the sheet or add the term",
       *off.flat_map do |property, by_value|
         ["  #{property} (#{Profile::VOCABULARIES.dig(property, :files).join(', ')})",
          *by_value.map { |value, ids| off_line(property, value, ids) }]
       end]
    end

    def off_line(property, value, ids)
      line = "    #{value}: #{ids.size} #{ids.one? ? 'row' : 'rows'} (#{sample(ids)})"
      suggestion = Profile.suggestion(Profile::VOCABULARIES[property], value)
      suggestion ? "#{line}, did you mean #{suggestion}?" : line
    end

    def sample(ids)
      ids.first(3).join(', ') + (ids.size > 3 ? ', …' : '')
    end
  end
end
