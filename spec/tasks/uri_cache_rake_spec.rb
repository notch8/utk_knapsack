# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'utk:uri_cache rake tasks' do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?('utk:uri_cache:import')
  end

  let(:json_file) { Rails.root.join('tmp', 'test_uri_caches.json').to_s }

  after do
    Rake::Task.tasks.each(&:reenable)
    FileUtils.rm_f(json_file)
    ENV.delete('JSON_FILE')
  end

  describe 'utk:uri_cache:seed' do
    let(:csv_file) { Rails.root.join('tmp', 'test_uri_caches.csv').to_s }

    after do
      FileUtils.rm_f(csv_file)
      ENV.delete('CSV_FILE')
    end

    before do
      File.write(csv_file, "uri,value\nhttp://example.com/given,Given\nhttp://example.com/fetched,\nhttp://example.com/broken,\n")
      ENV['CSV_FILE'] = csv_file
      allow(UriLabelResolver).to receive(:lookup).and_call_original
      allow(UriLabelResolver).to receive(:lookup).with('http://example.com/fetched') do |uri|
        UriCache.record_success(uri, 'Fetched').value
      end
      allow(UriLabelResolver).to receive(:lookup).with('http://example.com/broken') do |uri|
        UriCache.record_failure(uri, reason: 'Not Found(404)', permanent: true)
        nil
      end
    end

    it 'counts only the uris that gained a label' do
      expect { Rake::Task['utk:uri_cache:seed'].invoke }.to output(/Seeded 2 new/).to_stdout

      expect(UriCache.where(status: 'resolved').pluck(:uri, :value))
        .to contain_exactly(['http://example.com/given', 'Given'], ['http://example.com/fetched', 'Fetched'])
      expect(UriCache.find_by(uri: 'http://example.com/broken')).to have_attributes(status: 'failed')
    end

    it 'looks up a uri whose CSV value is failure text from the old resolver' do
      File.write(csv_file, "uri,value\nhttp://example.com/fetched,http://example.com/fetched (Failed to load URI)\n")

      Rake::Task['utk:uri_cache:seed'].invoke

      expect(UriCache.find_by(uri: 'http://example.com/fetched')).to have_attributes(status: 'resolved', value: 'Fetched')
    end

    it 'gives a label to a uri that failed to resolve' do
      create(:uri_cache, uri: 'http://example.com/given', status: 'failed', value: nil, reason: '(499)')

      Rake::Task['utk:uri_cache:seed'].invoke

      expect(UriCache.find_by(uri: 'http://example.com/given')).to have_attributes(status: 'resolved', value: 'Given')
    end
  end

  describe 'utk:uri_cache:export' do
    it 'carries a failure with its retry state' do
      create(:uri_cache, uri: 'http://example.com/gone', status: 'failed', value: nil, reason: 'Not Found(404)',
                         permanent: true, attempts: 2, retry_after: Time.zone.parse('2026-10-01T00:00:00Z'))

      ENV['JSON_FILE'] = json_file
      expect { Rake::Task['utk:uri_cache:export'].invoke }.to output(/Exported 1/).to_stdout

      expect(JSON.parse(File.read(json_file)).first)
        .to include('status' => 'failed', 'value' => nil, 'reason' => 'Not Found(404)', 'permanent' => true,
                    'attempts' => 2, 'retry_after' => '2026-10-01T00:00:00.000000Z')
    end

    it 'writes all UriCache records to JSON' do
      create(:uri_cache, uri: 'http://example.com/1', value: 'Label One')
      create(:uri_cache, uri: 'http://example.com/2', value: 'Label Two')

      ENV['JSON_FILE'] = json_file
      expect { Rake::Task['utk:uri_cache:export'].invoke }.to output(/Exported 2/).to_stdout

      data = JSON.parse(File.read(json_file))
      expect(data.size).to eq(2)
      expect(data.map { |r| r['uri'] }).to contain_exactly('http://example.com/1', 'http://example.com/2')
      expect(data.first['created_at']).to match(/\.\d{6}Z\z/)
      expect(data.first['updated_at']).to match(/\.\d{6}Z\z/)
    end
  end

  describe 'utk:uri_cache:import' do
    let(:seed_data) do
      [
        { uri: 'http://example.com/a', value: 'Alpha', created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' },
        { uri: 'http://example.com/b', value: 'Beta', created_at: '2026-01-02T00:00:00Z', updated_at: '2026-01-02T00:00:00Z' }
      ]
    end

    before do
      File.write(json_file, JSON.generate(seed_data))
      ENV['JSON_FILE'] = json_file
    end

    it 'inserts new records' do
      expect { Rake::Task['utk:uri_cache:import'].invoke }.to output(/Imported 2/).to_stdout

      expect(UriCache.count).to eq(2)
      expect(UriCache.find_by(uri: 'http://example.com/a').value).to eq('Alpha')
      expect(UriCache.find_by(uri: 'http://example.com/b').value).to eq('Beta')
    end

    it 'is idempotent' do
      Rake::Task['utk:uri_cache:import'].invoke
      Rake::Task['utk:uri_cache:import'].reenable

      expect { Rake::Task['utk:uri_cache:import'].invoke }.to output(/Imported 2/).to_stdout
      expect(UriCache.count).to eq(2)
    end

    it 'updates existing records on duplicate uri and preserves source timestamps' do
      create(:uri_cache, uri: 'http://example.com/a', value: 'Old Value')

      expect { Rake::Task['utk:uri_cache:import'].invoke }.to output(/Imported 2/).to_stdout

      record = UriCache.find_by(uri: 'http://example.com/a')
      expect(record.value).to eq('Alpha')
      expect(record.created_at).to eq(Time.zone.parse('2026-01-01T00:00:00Z'))
      expect(record.updated_at).to eq(Time.zone.parse('2026-01-01T00:00:00Z'))
    end

    it 'imports a failure exported with its retry state' do
      File.write(json_file, JSON.generate([{ uri: 'http://example.com/gone', value: nil, status: 'failed',
                                             reason: 'Not Found(404)', permanent: true, attempts: 2,
                                             retry_after: '2026-10-01T00:00:00Z',
                                             created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' }]))

      expect { Rake::Task['utk:uri_cache:import'].invoke }.to output(/Imported 1/).to_stdout
      expect(UriCache.find_by(uri: 'http://example.com/gone'))
        .to have_attributes(status: 'failed', reason: 'Not Found(404)', permanent: true, attempts: 2)
    end

    it 'marks failure text from an older export as a failure, not a label' do
      uri = 'http://id.loc.gov/authorities/subjects/sh2009007848'
      File.write(json_file, JSON.generate([{ uri:, value: "#{uri} (Failed to load URI) - Deleted heading.",
                                             created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' }]))

      Rake::Task['utk:uri_cache:import'].invoke

      expect(UriCache.find_by(uri:)).to have_attributes(status: 'failed', value: nil, reason: 'Deleted heading.',
                                                        permanent: true)
    end

    context 'when a uri already has a label here' do
      let(:uri) { 'http://id.loc.gov/authorities/subjects/sh2009007848' }

      before { create(:uri_cache, uri:, value: 'Good label') }

      it 'keeps the label over an exported failure' do
        File.write(json_file, JSON.generate([{ uri:, value: nil, status: 'failed', reason: 'Not Found(404)',
                                               permanent: true, attempts: 1, retry_after: '2026-10-01T00:00:00Z',
                                               created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' }]))

        Rake::Task['utk:uri_cache:import'].invoke

        expect(UriCache.find_by(uri:)).to have_attributes(status: 'resolved', value: 'Good label')
      end

      it 'keeps the label over failure text from an older export' do
        File.write(json_file, JSON.generate([{ uri:, value: "#{uri} (Failed to load URI) - Deleted heading.",
                                               created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' }]))

        Rake::Task['utk:uri_cache:import'].invoke

        expect(UriCache.find_by(uri:)).to have_attributes(status: 'resolved', value: 'Good label')
      end
    end

    it 'skips a row marked resolved with no label' do
      create(:uri_cache, uri: 'http://example.com/a', value: 'Good label')
      File.write(json_file, JSON.generate([{ uri: 'http://example.com/a', value: '', status: 'resolved',
                                             created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' },
                                           { uri: 'http://example.com/new', value: nil, status: 'resolved',
                                             created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z' }]))

      expect { Rake::Task['utk:uri_cache:import'].invoke }.to output(/Imported 0/).to_stdout
      expect(UriCache.find_by(uri: 'http://example.com/a').value).to eq 'Good label'
      expect(UriCache.exists?(uri: 'http://example.com/new')).to be false
    end

    it 'replaces a local failure with an exported label' do
      create(:uri_cache, uri: 'http://example.com/a', status: 'failed', value: nil, reason: 'timeout')

      Rake::Task['utk:uri_cache:import'].invoke

      expect(UriCache.find_by(uri: 'http://example.com/a')).to have_attributes(status: 'resolved', value: 'Alpha')
    end

    it 'aborts when file does not exist' do
      ENV['JSON_FILE'] = '/nonexistent/file.json'
      expect { Rake::Task['utk:uri_cache:import'].invoke }.to raise_error(SystemExit)
    end
  end
end
