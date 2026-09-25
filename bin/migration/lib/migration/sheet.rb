# frozen_string_literal: true

module Migration
  class Sheet
    attr_reader :headers, :rows

    class << self
      def read(path)
        table = CSV.read(path, headers: true, encoding: 'bom|utf-8')
        new(table.headers, table.to_a.drop(1).map { |values| table.headers.zip(values).to_h })
      end
    end

    def initialize(headers, rows)
      @headers = headers
      @rows = rows
      @works = rows.reject { |row| collection?(row) }.to_h { |row| [row['source_identifier'], row] }
    end

    def identifiers
      rows.map { |row| row['source_identifier'] }.compact.uniq
    end

    def collection?(row)
      row['model'] == 'Collection'
    end

    def root_of(source_id, seen = [])
      parents = @works[source_id]&.fetch('parents', nil).to_s.split('|').map(&:strip)
      parent = parents.find { |p| @works.key?(p) && !seen.include?(p) }
      parent ? root_of(parent, seen + [source_id]) : source_id
    end

    def work_count
      @works.keys.map { |id| root_of(id) }.uniq.size
    end

    def first_works(limit)
      roots = @works.keys.map { |id| root_of(id) }.uniq.first(limit)
      Sheet.new(headers, rows.select { |row| !collection?(row) && roots.include?(root_of(row['source_identifier'])) })
    end

    def write(path)
      CSV.open(path, 'w') do |csv|
        csv << headers
        rows.each { |row| csv << headers.map { |h| row[h] } }
      end
    end
  end
end
