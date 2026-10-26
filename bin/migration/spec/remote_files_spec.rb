# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe Migration::RemoteFiles do
  def problems(responses, listings = {})
    rows = responses.keys.each_with_index.map { |url, i| { 'source_identifier' => "w:#{i + 1}", 'remote_files' => url } }
    described_class.new(rows, fetch: ->(url) { responses.fetch(url) }, listing: ->(folder) { listings[folder] }).problems
  end

  it 'passes files that come back as themselves' do
    expect(problems('https://a/1.xml' => ['206', 'text/xml', '<mods/>'], 'https://a/2.jp2' => ['200', 'image/jp2', ''])).to be_nil
  end

  it 'flags an HTML page, by content type or by body' do
    expect(problems('https://a/1' => ['200', 'text/html; charset=utf-8', 'x'],
                    'https://a/2' => ['200', 'application/octet-stream', '<!DOCTYPE html><title>bot?</title>'])).to eq [
                      'BAD REMOTE FILES: 2 of 2',
                      '  w:1 https://a/1: an HTML page (text/html; charset=utf-8)',
                      '  w:2 https://a/2: an HTML page (application/octet-stream)'
                    ]
  end

  it 'flags an error status' do
    expect(problems('https://a/1' => ['404', 'text/plain', ''])).to eq ['BAD REMOTE FILES: 1 of 1', '  w:1 https://a/1: HTTP 404']
  end

  it 'checks each url in a multi-valued cell' do
    rows = [{ 'source_identifier' => 'w:1', 'remote_files' => 'https://a/1 | https://a/2' }]
    seen = []
    described_class.new(rows, fetch: ->(url) { seen << url && ['200', 'image/tiff', ''] }, listing: ->(_) {}).problems
    expect(seen).to contain_exactly('https://a/1', 'https://a/2')
  end

  it 'fetches only the files missing from their folder listing' do
    seen = []
    rows = [{ 'source_identifier' => 'w:1', 'remote_files' => 'https://a/x/1%201.pdf | https://a/x/2.pdf' }]
    described_class.new(rows, fetch: ->(url) { seen << url && ['200', 'application/pdf', ''] },
                              listing: ->(folder) { Set['1 1.pdf'] if folder == 'https://a/x/' }).problems
    expect(seen).to eq ['https://a/x/2.pdf']
  end

  it 'names the listed file a missing one nearly matches' do
    expect(problems({ 'https://a/x/w_1_OBJ' => ['404', 'text/html', ''] }, 'https://a/x/' => Set['w1_OBJ.jp2']))
      .to eq ['BAD REMOTE FILES: 1 of 1', '  w:1 https://a/x/w_1_OBJ: HTTP 404; the folder has w1_OBJ.jp2']
  end
end
