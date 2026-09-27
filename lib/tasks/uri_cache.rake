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
      value = nil if value&.start_with?(uri.to_s)
      next if uri.blank? || UriCache.find_by(uri:)&.resolved?

      labeled = value.present? ? UriCache.record_success(uri, value) : UriLabelResolver.lookup(uri)
      count += 1 if labeled
    end
    puts "Seeded #{count} new URI cache entries"
  end

  desc 'Export UriCache records to JSON (default: db/seeds/uri_caches.json)'
  task export: :environment do
    file = ENV.fetch('JSON_FILE', HykuKnapsack::Engine.root.join('db/seeds/uri_caches.json').to_s)
    records = UriCache.order(:id).map do |cache|
      cache.slice(:uri, :value, :status, :reason, :permanent, :attempts)
           .merge(retry_after: cache.retry_after&.iso8601(6),
                  created_at: cache.created_at.iso8601(6), updated_at: cache.updated_at.iso8601(6))
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
        status: r['status'] || UriCache::RESOLVED,
        reason: r['reason'],
        permanent: r['permanent'] || false,
        attempts: r['attempts'] || 0,
        retry_after: r['retry_after'] && Time.zone.parse(r['retry_after']),
        created_at: Time.zone.parse(r['created_at']),
        updated_at: Time.zone.parse(r['updated_at'])
      }
    end

    rows.reject! { |row| row[:status] == UriCache::RESOLVED && row[:value].blank? }
    labeled, unlabeled = rows.partition do |row|
      row[:status] == UriCache::RESOLVED && !row[:value].start_with?(row[:uri])
    end

    # rubocop:disable Rails/SkipsModelValidations
    upserted = labeled.any? ? UriCache.upsert_all(labeled, unique_by: :uri).length : 0
    inserted = unlabeled.any? ? UriCache.insert_all(unlabeled, unique_by: :uri).length : 0
    # rubocop:enable Rails/SkipsModelValidations
    UriCache.reclassify_legacy_failures!
    puts "Imported #{upserted + inserted} URI cache entries from #{file}"
  end

  desc 'Re-resolve all cached URIs from their remote sources'
  task refresh: :environment do
    UriCache.update_all_caches!
    puts "Refreshed #{UriCache.count} URI cache entries"
  end
end
