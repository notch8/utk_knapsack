# frozen_string_literal: true

require 'net/http'
require 'uri'

Dir.chdir(ENV.fetch('HYRAX_DERIVATIVES_PATH'))
$stdin.each_line do |line|
  url, path = line.chomp.split("\t", 2)
  uri = URI(url)
  File.open(path, 'rb') do |io|
    request = Net::HTTP::Put.new(uri)
    request['Content-Length'] = io.size.to_s
    request.body_stream = io
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 600) { |http| http.request(request) }
    puts "#{response.code}\t#{path}"
  end
end
