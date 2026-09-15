# frozen_string_literal: true

namespace :utk do
  namespace :uri_cache do
    desc 'Seed UriCache from a CSV file (columns: uri, value)'
    task seed: :environment do
      require 'csv'
      file = ENV.fetch('CSV_FILE') { abort 'Usage: rake utk:uri_cache:seed CSV_FILE=path/to/uris.csv' }

      count = 0
      CSV.foreach(file, headers: true) do |row|
        uri = row['uri']&.strip
        value = row['value']&.strip
        next if uri.blank?

        UriCache.find_or_create_by!(uri: uri) do |cache|
          cache.value = value.presence || UriLabelResolver.label_for(uri)
          count += 1
        end
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
        Rails.logger.warn("Skipping #{uri}: #{e.message}")
      end
      puts "Seeded #{count} new URI cache entries"
    end

    desc 'Re-resolve all cached URIs from their remote sources'
    task refresh: :environment do
      UriCache.update_all_caches!
      puts "Refreshed #{UriCache.count} URI cache entries"
    end
  end
end
