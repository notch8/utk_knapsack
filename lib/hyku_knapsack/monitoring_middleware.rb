# frozen_string_literal: true

require 'json'
require 'rack/utils'

module HykuKnapsack
  # Serves Puma's runtime stats ahead of the rest of the middleware stack, so the
  # response never touches the database, Redis, or tenant resolution.
  #
  #   GET /monitoring/puma_stats  JSON, as in hykuup_knapsack
  #   GET /monitoring/metrics     Prometheus text format, for the web autoscaler
  #
  # Set MONITORING_TOKEN to require `Authorization: Bearer <token>` (or `?token=`).
  class MonitoringMiddleware
    PUMA_STATS_PATH = '/monitoring/puma_stats'
    METRICS_PATH = '/monitoring/metrics'
    PATHS = [PUMA_STATS_PATH, METRICS_PATH].freeze

    # key => [metric type, help]; absent keys (e.g. cluster mode) are skipped.
    METRICS = {
      'backlog' => ['gauge', 'Requests accepted but not yet assigned a thread'],
      'running' => ['gauge', 'Threads currently spawned'],
      'pool_capacity' => ['gauge', 'Additional requests this process could accept now (0 = saturated)'],
      'max_threads' => ['gauge', 'Configured maximum threads'],
      'requests_count' => ['counter', 'Requests served since boot']
    }.freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      path = env['PATH_INFO']
      return @app.call(env) unless PATHS.include?(path)
      return respond(405, 'error' => 'method not allowed') unless env['REQUEST_METHOD'] == 'GET'
      return respond(401, 'error' => 'unauthorized') unless authorized?(env)

      stats = puma_stats
      return respond(503, 'error' => 'puma stats unavailable') unless stats

      path == METRICS_PATH ? respond_metrics(stats) : respond(200, stats)
    end

    private

    def respond(status, body)
      json = JSON.generate(body)
      [status, { 'Content-Type' => 'application/json', 'Content-Length' => json.bytesize.to_s }, [json]]
    end

    def respond_metrics(stats)
      text = prometheus_text(stats.transform_keys(&:to_s))
      [200, { 'Content-Type' => 'text/plain; version=0.0.4', 'Content-Length' => text.bytesize.to_s }, [text]]
    end

    def prometheus_text(stats)
      METRICS.filter_map do |key, (type, help)|
        next unless stats[key].is_a?(Numeric)

        name = "puma_#{key}"
        "# HELP #{name} #{help}\n# TYPE #{name} #{type}\n#{name} #{stats[key]}\n"
      end.join
    end

    def authorized?(env)
      expected = ENV['MONITORING_TOKEN']
      return true if expected.blank?

      provided = bearer_token(env) || Rack::Utils.parse_query(env['QUERY_STRING'].to_s)['token']
      return false unless provided.is_a?(String) && provided.bytesize == expected.bytesize

      Rack::Utils.secure_compare(expected, provided)
    end

    def bearer_token(env)
      header = env['HTTP_AUTHORIZATION'].to_s
      header.start_with?('Bearer ') ? header.delete_prefix('Bearer ') : nil
    end

    # Puma.stats_hash raises NoMethodError until the launcher registers its stats
    # (rake, console), which becomes a 503.
    def puma_stats
      return nil unless defined?(Puma) && Puma.respond_to?(:stats_hash)

      Puma.stats_hash
    rescue NoMethodError
      nil
    end
  end
end
