# frozen_string_literal: true
# Pull the lookup for one sheet, by identifier rather than by prefix.
#
#   ruby collection_lookup.rb sheets/collections_ruskin.csv lookup/ruskin.jsonl
#
# A sheet is the unit of work, not an identifier prefix: there are 2,477
# prefixes across the tenant and a sheet may span several, so a prefix query
# can silently miss members.
require 'csv'
require 'json'
require 'net/http'
require 'uri'

TENANT = ENV.fetch('TENANT', '56e0eb81-c2d5-4d5d-9171-b251bf7299a4')
SOLR = URI("http://#{ENV.fetch('SOLR_HOST')}:#{ENV.fetch('SOLR_PORT')}/solr/#{TENANT}/select")
AUTH = [ENV.fetch('SOLR_ADMIN_USER'), ENV.fetch('SOLR_ADMIN_PASSWORD')].freeze
FIELDS = %w[id bulkrax_identifier_tesim digest_ssim mime_type_ssi
            file_size_lts label_tesim].join(',')
BATCH = Integer(ENV.fetch('BATCH', 500))

sheet = ARGV.fetch(0)
out_path = ARGV.fetch(1)

identifiers = CSV.read(sheet, headers: true).map { |row| row['source_identifier'] }.compact.uniq
warn "#{sheet}: #{identifiers.size} identifiers"

found = 0
started = Time.now
File.open(out_path, 'w') do |out|
  Net::HTTP.start(SOLR.hostname, SOLR.port) do |http|
    identifiers.each_slice(BATCH) do |slice|
      query = slice.map { |i| %("#{i.gsub('"', '\"')}") }.join(' OR ')
      params = { q: "bulkrax_identifier_tesim:(#{query})", rows: BATCH * 2,
                 fl: FIELDS, wt: 'json', omitHeader: 'true' }
      req = Net::HTTP::Post.new(SOLR.path)
      req.basic_auth(*AUTH)
      req.set_form_data(params)
      res = http.request(req)
      raise "solr #{res.code}: #{res.body[0, 200]}" unless res.is_a?(Net::HTTPSuccess)

      docs = JSON.parse(res.body).dig('response', 'docs') || []
      docs.each { |d| out.puts(d.to_json) }
      out.flush
      found += docs.size
      warn format('  %d/%d identifiers, %d docs, %.0fs',
                  [identifiers.index(slice.last).to_i + 1, identifiers.size].min,
                  identifiers.size, found, Time.now - started)
    end
  end
end

missing = identifiers.size - found
warn format('DONE %d docs for %d identifiers (%d unmatched) -> %s',
            found, identifiers.size, missing, out_path)
exit(missing.zero? ? 0 : 2)
