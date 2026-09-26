# frozen_string_literal: true

module Migration
  class Transform
    RENAMED_MODELS = { 'Image' => 'StillImage' }.freeze
    NON_WORK_MODELS = %w[Collection FileSet].freeze
    PASSED_OVER = %w[source_identifier model parents remote_files].freeze
    TEMPFILE_NAME = /\A([A-Z][A-Z_-]*)\d{8}-\d+-[a-z0-9]+\z/

    Result = Struct.new(:rows, :headers, :flagged, :stops, keyword_init: true)

    def initialize(sheet, lookup, skip_missing: false, excluded: [])
      @sheet = sheet
      @lookup = lookup
      @skip_missing = skip_missing
      @excluded = excluded
    end

    def call
      rows = @sheet.rows.map { |row| convert(row) }
      flagged = {}
      if @skip_missing
        flagged = problems(rows).group_by { |id, _| @sheet.root_of(id) }
                                .reject { |root, _| rows.find { |r| r['source_identifier'] == root }&.fetch('model') == 'Collection' }
        rows = rows.reject { |row| flagged.key?(@sheet.root_of(row['source_identifier'])) }
      end
      headers = rows.flat_map(&:keys).uniq
      Result.new(rows:, headers:, flagged:, stops: Preflight.new(rows, headers).stops)
    end

    private

    def convert(row)
      found = @lookup[row['source_identifier']]
      out = { 'source_identifier' => row['source_identifier'], 'id' => found&.fetch('id'),
              'model' => RENAMED_MODELS.fetch(row['model'].to_s, row['model']), 'parents' => row['parents'] }
      out['primary_identifier'] = row['source_identifier'] unless NON_WORK_MODELS.include?(out['model'])
      add_agents(out, row)
      add_passthrough(out, row)
      file_pointer(out, found) if out['model'] == 'FileSet' && found
      out
    end

    def add_agents(out, row)
      agents(row).each do |compound, entries|
        entries.each_with_index do |(name, role), i|
          out["#{compound}_name_#{i + 1}"] = name
          out["#{compound}_role_#{i + 1}"] = role
        end
      end
    end

    def add_passthrough(out, row)
      row.each do |header, value|
        next if header.nil? || PASSED_OVER.include?(header) || Profile::ROLE_FOR_COLUMN.key?(header)

        values = split(value)
        out[header] = values.join(' | ') unless values.empty?
      end
    end

    def agents(row)
      row.each_with_object({ 'creator' => [], 'contributor' => [] }) do |(header, value), acc|
        compound, role = Profile::ROLE_FOR_COLUMN[header]
        split(value).each { |name| acc[compound] << [name, role] } if compound
      end
    end

    def file_pointer(out, found)
      out['sha1'] = Array(found['digest_ssim']).first.to_s.delete_prefix('urn:sha1:')
      out['mime_type'] = found['mime_type_ssi']
      out['file_size'] = found['file_size_lts']
      label = Array(found['label_tesim']).first
      out['original_filename'] = TEMPFILE_NAME.match(label.to_s)&.[](1) || label
    end

    def split(cell)
      cell.to_s.split('|').flat_map { |v| unwrap(v.strip) }.map(&:strip).reject(&:empty?)
    end

    def unwrap(value)
      return [value] unless value.start_with?('[') && value.end_with?(']')

      parsed = JSON.parse(value)
      parsed.is_a?(Array) ? parsed.map(&:to_s) : [value]
    rescue JSON::ParserError
      [value]
    end

    def problems(rows)
      rows.each_with_object({}) do |row, acc|
        reasons = []
        reasons << 'not found in legacy Solr' if row['id'].nil?
        reasons << 'no digest in legacy Solr' if row['model'] == 'FileSet' && row['id'] && row['sha1'].to_s.empty?
        reasons << 'original missing in besties-fcrepo' if @excluded.include?(row['id'].to_s)
        acc[row['source_identifier']] = reasons if reasons.any?
      end
    end
  end
end
