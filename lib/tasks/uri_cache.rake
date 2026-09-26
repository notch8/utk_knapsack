# frozen_string_literal: true

namespace 'utk:uri_cache' do # rubocop:disable Metrics/BlockLength
  desc 'Seed UriCache from a CSV file (columns: uri, value)'
  task seed: :environment do
    require 'csv'
    file = ENV.fetch('CSV_FILE') { abort 'Usage: rake utk:uri_cache:seed CSV_FILE=path/to/uris.csv' }

    count = 0
    CSV.foreach(file, headers: true) do |row|
      uri = row['uri']&.strip
      value = row['value']&.strip
      next if uri.blank?

      UriCache.find_or_create_by!(uri:) do |cache|
        resolved = value.presence || UriLabelResolver.label_for(uri)
        next if resolved.start_with?(uri)

        cache.value = resolved
        count += 1
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Rails.logger.warn("Skipping #{uri}: #{e.message}")
    end
    puts "Seeded #{count} new URI cache entries"
  end

  desc 'Export UriCache records to JSON (default: db/seeds/uri_caches.json)'
  task export: :environment do
    file = ENV.fetch('JSON_FILE', HykuKnapsack::Engine.root.join('db/seeds/uri_caches.json').to_s)
    records = UriCache.order(:id).pluck(:uri, :value, :created_at, :updated_at).map do |uri, value, created_at, updated_at|
      { uri:, value:, created_at: created_at.iso8601(6), updated_at: updated_at.iso8601(6) }
    end
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, JSON.generate(records))
    puts "Exported #{records.size} URI cache entries to #{file}"
  end

  desc 'Import UriCache records from JSON (default: db/seeds/uri_caches.json)'
  task import: :environment do
    file = ENV.fetch('JSON_FILE', HykuKnapsack::Engine.root.join('db/seeds/uri_caches.json').to_s)
    abort "File not found: #{file}" unless File.exist?(file)

    records = JSON.parse(File.read(file))
    rows = records.map do |r|
      {
        uri: r['uri'],
        value: r['value'],
        created_at: Time.zone.parse(r['created_at']),
        updated_at: Time.zone.parse(r['updated_at'])
      }
    end

    result = UriCache.upsert_all(rows, unique_by: :uri) # rubocop:disable Rails/SkipsModelValidations
    puts "Imported #{result.length} URI cache entries from #{file}"
  end

  desc 'Re-resolve all cached URIs from their remote sources'
  task refresh: :environment do
    UriCache.update_all_caches!
    puts "Refreshed #{UriCache.count} URI cache entries"
  end
end
