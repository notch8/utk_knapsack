# frozen_string_literal: true

require 'json'
require 'rsolr'

mode, tenant = ARGV
solr = RSolr.connect(url: "#{ENV.fetch('SOLR_URL').chomp('/')}/#{tenant}")

if mode == 'cname'
  docs = solr.get('select', params: { q: 'generic_type_sim:Work', rows: 1, fl: 'account_cname_tesim' })['response']['docs']
  puts Array(docs.first && docs.first['account_cname_tesim']).first
  exit
end

fields = 'id,bulkrax_identifier_tesim,digest_ssim,mime_type_ssi,file_size_lts,label_tesim'
$stdin.each_line.map(&:strip).reject(&:empty?).each_slice(500) do |slice|
  query = slice.map { |id| %("#{id.gsub('"', '\"')}") }.join(' OR ')
  params = { q: "bulkrax_identifier_tesim:(#{query})", rows: 1000, fl: fields, qt: 'standard' }
  solr.post('select', data: params)['response']['docs'].each { |doc| puts doc.to_json }
end
