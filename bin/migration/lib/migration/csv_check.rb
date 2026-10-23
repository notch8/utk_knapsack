# frozen_string_literal: true

module Migration
  class CsvCheck
    def initialize(sheet, app, tenant)
      @sheet = sheet
      @app = app
      @tenant = tenant
    end

    def run!
      stops = CsvPreflight.new(@sheet.rows, @sheet.headers).stops
      stops += Array(RemoteFiles.new(@sheet.rows).problems)
      stops += target_stops
      abort(['🛑 Stopped before importing:', *stops].join("\n")) if stops.any?

      notes.each { |line| puts line }
      puts "✅ #{@sheet.rows.size} rows checked against #{@tenant}"
    end

    private

    def target_stops
      in_sheet = @sheet.identifiers
      missing = parents - in_sheet - existing.keys
      file_sets = rows_on_target.select { |row| row['model'] == 'FileSet' }
      [("MISSING PARENTS on #{@tenant}: #{missing.size} #{missing.first(5).inspect}" if missing.any?),
       (if under_collection.any?
          ["FILE SETS UNDER A COLLECTION: #{under_collection.size}; a file set's parent must be its work",
           *under_collection.first(5).map { |row| "  #{row['source_identifier']} -> #{row['parents']}" }]
        end),
       (if file_sets.any?
          ["FILE SETS ALREADY ON #{@tenant}: #{file_sets.size}; an import would not replace their files",
           '  list them with bin/migration/delete_file_sets, then delete with --apply once approved',
           *file_sets.first(5).map { |row| "  #{row['source_identifier']}" }]
        end)].compact.flatten
    end

    def notes
      works = rows_on_target.reject { |row| row['model'] == 'FileSet' }
      works.any? ? ["ℹ️  #{works.size} works already on #{@tenant}; the import updates their metadata from the sheet"] : []
    end

    def parents
      @sheet.rows.flat_map { |row| row['parents'].to_s.split('|').map(&:strip) }.reject(&:empty?).uniq
    end

    def under_collection
      @under_collection ||= collections_named.then do |collections|
        @sheet.rows.select do |row|
          row['model'] == 'FileSet' && row['parents'].to_s.split('|').map(&:strip).intersect?(collections)
        end
      end
    end

    def collections_named
      collections = @sheet.rows.filter_map { |row| row['source_identifier'] if row['model'] == 'Collection' }
      collections + existing.select { |_, model| model.to_s.include?('Collection') }.keys
    end

    def rows_on_target
      @sheet.rows.select { |row| existing.key?(row['source_identifier']) }
    end

    def existing
      @existing ||= {}.tap do |found|
        output = []
        status = @app.run('existing', @tenant, stdin: (@sheet.identifiers | parents).join("\n"), ruby: 'bundle exec rails runner') do |line|
          if line.start_with?('MARKER ')
            identifier, model = line.delete_prefix('MARKER ').chomp.split("\t", 2)
            found[identifier] = model
          else
            output << line
          end
        end
        abort "🛑 Could not read #{@tenant}\n#{output.reject { |line| line.start_with?('** ', "\tfrom ") }.last(20).join}" unless status.success?
      end
    end
  end
end
