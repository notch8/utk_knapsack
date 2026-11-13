# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::MonitoringMiddleware do
  let(:downstream_response) { [200, { 'Content-Type' => 'text/plain' }, ['downstream']] }
  let(:app) { ->(_env) { downstream_response } }
  let(:middleware) { described_class.new(app) }
  let(:puma_stats) do
    { backlog: 2, running: 7, pool_capacity: 5, max_threads: 7, requests_count: 12_345 }
  end

  def request(path: described_class::PUMA_STATS_PATH, method: 'GET', query: '', headers: {})
    env = Rack::MockRequest.env_for("#{path}#{query.empty? ? '' : "?#{query}"}", method:)
    headers.each { |key, value| env[key] = value }
    middleware.call(env)
  end

  def body_json(response)
    JSON.parse(response.last.join)
  end

  before do
    allow(Puma).to receive(:stats_hash).and_return(puma_stats)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('MONITORING_TOKEN').and_return(token)
  end

  let(:token) { nil }

  describe '#call' do
    it 'passes other paths through to the app' do
      expect(request(path: '/catalog')).to eq(downstream_response)
    end

    it 'returns 405 for non-GET requests' do
      status, = response = request(method: 'POST')
      expect(status).to eq(405)
      expect(body_json(response)).to eq('error' => 'method not allowed')
    end

    context 'with /monitoring/puma_stats' do
      it 'returns the stats as JSON' do
        status, headers, = response = request
        expect(status).to eq(200)
        expect(headers['Content-Type']).to eq('application/json')
        expect(body_json(response)).to eq(puma_stats.stringify_keys)
      end
    end

    context 'with /monitoring/metrics' do
      let(:path) { described_class::METRICS_PATH }

      it 'returns Prometheus text with a gauge or counter per stat' do
        status, headers, body = request(path:)
        text = body.join
        expect(status).to eq(200)
        expect(headers['Content-Type']).to eq('text/plain; version=0.0.4')
        expect(headers['Content-Length']).to eq(text.bytesize.to_s)
        expect(text).to include("# TYPE puma_backlog gauge\npuma_backlog 2\n")
        expect(text).to include("# TYPE puma_requests_count counter\npuma_requests_count 12345\n")
      end

      it 'skips stats Puma does not report' do
        allow(Puma).to receive(:stats_hash).and_return(backlog: 0)
        text = request(path:).last.join
        expect(text).to include('puma_backlog 0')
        expect(text).not_to include('puma_pool_capacity')
      end
    end

    context 'when Puma stats are unavailable' do
      it 'returns 503 when the stats object is not registered' do
        allow(Puma).to receive(:stats_hash).and_raise(NoMethodError)
        status, = response = request
        expect(status).to eq(503)
        expect(body_json(response)).to eq('error' => 'puma stats unavailable')
      end

      it 'returns 503 when Puma does not respond to stats_hash' do
        allow(Puma).to receive(:respond_to?).and_call_original
        allow(Puma).to receive(:respond_to?).with(:stats_hash).and_return(false)
        expect(request.first).to eq(503)
      end
    end

    context 'when MONITORING_TOKEN is set' do
      let(:token) { 'sekret' }

      it 'returns 401 without a token' do
        expect(request.first).to eq(401)
      end

      it 'returns 401 with a wrong token of the same length' do
        expect(request(headers: { 'HTTP_AUTHORIZATION' => 'Bearer nekret' }).first).to eq(401)
      end

      it 'returns 401 with a non-Bearer Authorization header' do
        expect(request(headers: { 'HTTP_AUTHORIZATION' => 'Basic sekret' }).first).to eq(401)
      end

      it 'accepts the correct bearer token' do
        expect(request(headers: { 'HTTP_AUTHORIZATION' => 'Bearer sekret' }).first).to eq(200)
      end

      it 'accepts the correct token query param' do
        expect(request(query: 'token=sekret').first).to eq(200)
      end
    end

    context 'when MONITORING_TOKEN is empty' do
      let(:token) { '' }

      it 'allows access' do
        expect(request.first).to eq(200)
      end
    end
  end
end
