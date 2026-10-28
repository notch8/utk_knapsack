# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::ImporterJobDecorator do
  let(:dir) { Dir.mktmpdir }
  let(:downloaded) { File.join(dir, 'burial_001.tif').tap { |path| File.write(path, 'tif') } }
  let(:pending) { File.join(dir, 'burial_002.tif') }
  let(:importer) { instance_double(Bulkrax::Importer, parser_fields:) }
  let(:job) { Bulkrax::ImporterJob.new }

  after { FileUtils.remove_entry(dir) }

  context 'when a cloud file is still downloading' do
    let(:parser_fields) do
      { 'cloud_file_paths' => { '0' => { 'file_size' => '3' }, '1' => { 'file_size' => '3' } },
        'original_file_paths' => [downloaded, pending] }
    end

    it 'waits for it instead of failing the import' do
      expect(job.send(:all_files_completed?, importer)).to be false
    end
  end

  context 'when every cloud file has downloaded' do
    let(:parser_fields) do
      { 'cloud_file_paths' => { '0' => { 'file_size' => '3' } }, 'original_file_paths' => [downloaded] }
    end

    it 'lets the import run' do
      expect(job.send(:all_files_completed?, importer)).to be true
    end
  end
end
