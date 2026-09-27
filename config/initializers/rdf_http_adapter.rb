# frozen_string_literal: true

require 'faraday/follow_redirects'
require 'faraday/retry'

RDF::Util::File::FaradayAdapter.conn = Faraday.new do |conn|
  conn.options.open_timeout = 5
  conn.options.timeout = 15
  conn.request :retry, max: 2, interval: 0.5, backoff_factor: 2, max_interval: 2,
                       retry_statuses: [429, 499, 502, 503, 504],
                       exceptions: [Faraday::ConnectionFailed, Faraday::RetriableResponse]
  conn.response :follow_redirects
  conn.adapter Faraday.default_adapter
end

RDF::Util::File.http_adapter = RDF::Util::File::FaradayAdapter
