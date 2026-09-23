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

  describe 'utk:uri_cache:export' do
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

    it 'aborts when file does not exist' do
      ENV['JSON_FILE'] = '/nonexistent/file.json'
      expect { Rake::Task['utk:uri_cache:import'].invoke }.to raise_error(SystemExit)
    end
  end
end
