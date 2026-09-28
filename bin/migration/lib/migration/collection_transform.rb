# frozen_string_literal: true

module Migration
  class CollectionTransform < Transform
    def initialize(sheet)
      super(sheet, {})
    end

    def call
      rows = @sheet.rows.map { |row| convert(row) }
      headers = rows.flat_map(&:keys).uniq
      Result.new(rows:, headers:, flagged: {}, stops: Preflight.new(rows, headers, looked_up: false).stops)
    end

    private

    def convert(row)
      out = { 'source_identifier' => row['source_identifier'], 'model' => row['model'],
              'primary_identifier' => row['source_identifier'], 'parents' => row['parents'] }
      add_agents(out, row)
      add_passthrough(out, row)
      out
    end
  end
end
