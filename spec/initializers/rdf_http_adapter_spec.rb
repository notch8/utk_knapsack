# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RDF HTTP adapter' do
  let(:uri) { 'http://vocab.getty.edu/aat/300022208' }
  let(:download_url) { "https://vocab.getty.edu/download/nt?uri=#{uri}" }
  let(:ntriples) { File.read(HykuKnapsack::Engine.root.join('spec', 'fixtures', 'rdf_data', 'getty.nt')) }
  let(:ntriples_response) { { status: 200, body: ntriples, headers: { 'Content-Type' => 'application/n-triples' } } }

  before do
    stub_request(:get, uri).to_return(status: 301, headers: { 'Location' => 'https://vocab.getty.edu/aat/300022208' })
    stub_request(:get, 'https://vocab.getty.edu/aat/300022208').to_return(status: 303, headers: { 'Location' => download_url })
  end

  it 'follows Getty redirects to the label' do
    stub_request(:get, download_url).to_return(ntriples_response)

    expect(UriLabelResolver.lookup(uri)).to eq 'Postmodern'
  end

  it 'retries a 499 and resolves when Getty recovers' do
    stub_request(:get, download_url).to_return({ status: 499 }, ntriples_response)

    expect(UriLabelResolver.lookup(uri)).to eq 'Postmodern'
  end

  it 'gives up after two retries and records a temporary failure' do
    stub_request(:get, download_url).to_return(status: 503)

    expect(UriLabelResolver.lookup(uri)).to be_nil
    expect(a_request(:get, download_url)).to have_been_made.times(3)
    expect(UriCache.find_by(uri:)).to have_attributes(status: 'failed', permanent: false)
  end

  it 'does not wait out a long Retry-After' do
    rate_limited = 'http://id.loc.gov/authorities/names/n79007751'
    stub_request(:get, rate_limited).to_return(status: 429, headers: { 'Retry-After' => '3' })

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect(UriLabelResolver.lookup(rate_limited)).to be_nil
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 2
    expect(a_request(:get, rate_limited)).to have_been_made.once
    expect(UriCache.find_by(uri: rate_limited)).to have_attributes(status: 'failed', permanent: false)
  end

  it 'records a 404 as permanent without retrying' do
    stub_request(:get, download_url).to_return(status: 404)

    expect(UriLabelResolver.lookup(uri)).to be_nil
    expect(a_request(:get, download_url)).to have_been_made.once
    expect(UriCache.find_by(uri:)).to have_attributes(status: 'failed', permanent: true)
  end

  it 'does not retry a read timeout' do
    stub_request(:get, download_url).to_raise(Net::ReadTimeout)

    expect(UriLabelResolver.lookup(uri)).to be_nil
    expect(a_request(:get, download_url)).to have_been_made.once
    expect(UriCache.find_by(uri:)).to have_attributes(status: 'failed', permanent: false)
  end

  it 'bounds how long a request can wait' do
    options = RDF::Util::File.http_adapter.conn.options

    expect([options.open_timeout, options.timeout]).to eq [5, 15]
  end
end
