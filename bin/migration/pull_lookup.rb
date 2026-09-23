# frozen_string_literal: true
# Pull the identifier -> uuid/file lookup for the whole tenant, once.
#   ruby pull_lookup.rb /tmp/lookup.jsonl
require 'net/http'
require 'json'
require 'uri'

TENANT = ENV.fetch('TENANT', '56e0eb81-c2d5-4d5d-9171-b251bf7299a4')
# Inside a pod the credentials arrive as one SOLR_URL; a dev shell sets the four
# separately. Take whichever is there so the script runs either place unchanged.
HOST, PORT, USER, PASSWORD =
  if (url = ENV['SOLR_URL'])
    u = URI(url)
    [u.host, u.port, u.user, u.password]
  else
    [ENV.fetch('SOLR_HOST'), Integer(ENV.fetch('SOLR_PORT')),
     ENV.fetch('SOLR_ADMIN_USER'), ENV.fetch('SOLR_ADMIN_PASSWORD')]
  end
SOLR = URI("http://#{HOST}:#{PORT}/solr/#{TENANT}/select")
AUTH = [USER, PASSWORD].freeze
FIELDS = %w[id bulkrax_identifier_tesim digest_ssim mime_type_ssi
            file_size_lts label_tesim].join(',')
OUT = ARGV.fetch(0, '/tmp/lookup.jsonl')
ROWS = 2000

cursor = '*'
total = 0
started = Time.now

File.open(OUT, 'w') do |out|
  Net::HTTP.start(SOLR.hostname, SOLR.port) do |http|
    loop do
      params = { q: 'bulkrax_identifier_tesim:*', rows: ROWS, fl: FIELDS, qt: 'standard',
                 sort: 'id asc', wt: 'json', omitHeader: 'true', cursorMark: cursor }
      req = Net::HTTP::Get.new("#{SOLR.path}?#{URI.encode_www_form(params)}")
      req.basic_auth(*AUTH)
      res = http.request(req)
      raise "solr #{res.code}" unless res.is_a?(Net::HTTPSuccess)

      body = JSON.parse(res.body)
      docs = body.dig('response', 'docs') || []
      docs.each { |d| out.puts(d.to_json) }
      out.flush
      total += docs.size

      nxt = body['nextCursorMark']
      warn format('%d rows, %.0fs', total, Time.now - started) if (total % 100_000).zero?
      break if nxt.nil? || nxt == cursor || docs.empty?
      cursor = nxt
    end
  end
end
warn format('DONE %d rows in %.0fs -> %s', total, Time.now - started, OUT)
