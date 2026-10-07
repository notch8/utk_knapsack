# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::HykuIndexingDecorator do
  subject(:all_text) { BookIndexer.new(resource: work).to_solr['all_text_tsimv'] }

  let(:work) { Hyrax.persister.save(resource: Book.new(title: ['Book'], member_ids:)) }
  let(:reads) { [] }
  let(:solr_ids) { [] }

  before do
    allow(Valkyrie::StorageAdapter).to receive(:adapter_for).and_wrap_original do |original, **args|
      original.call(**args).tap do |adapter|
        allow(adapter).to receive(:find_by).and_wrap_original do |find_by, id:|
          reads << id.to_s
          find_by.call(id:)
        end
      end
    end
  end

  let(:pdf) { { 'has_model_ssim' => ['Hyrax::FileSet'], 'mime_type_ssi' => 'application/pdf' } }

  after { solr_ids.each { |id| Hyrax::SolrService.delete(id) } }

  def index(id, text = nil, **fields)
    solr_ids << id
    fields = { 'has_model_ssim' => ['Hyrax::FileSet'] } if fields.empty?
    Hyrax::SolrService.add({ 'id' => id, 'all_text_tsimv' => text, **fields }.compact, commit: true)
    Valkyrie::ID.new(id)
  end

  context 'with page file sets and a child work' do
    let(:member_ids) do
      page1 = index('i295-page-1', ['first page'])
      child = index('i295-child', ['child work'], 'has_model_ssim' => ['Book'], 'generic_type_sim' => ['Work'])
      [index('i295-page-2', ['second page']), child, page1]
    end

    it 'joins the file sets\' indexed text in member order, then the child work\'s' do
      expect(all_text).to eq 'second page first page child work'
    end
  end

  context 'with a text/plain file set whose original is in storage' do
    let(:dir) { Pathname.new(Dir.mktmpdir(nil, FileUtils.mkdir_p(Valkyrie::StorageAdapter.find(:disk).base_path).first)) }
    let(:file_set) { Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ['OCR for page 1'])) }
    let(:member_ids) { [file_set.id, index('i295-page', ['iiif print text'])] }

    before do
      path = dir.join('ocr.txt').tap { |p| File.write(p, 'islandora ocr') }
      original = Hyrax.persister.save(resource: Hyrax::FileMetadata.new(
        file_identifier: Valkyrie::ID.new("disk://#{path}"), file_set_id: file_set.id, mime_type: 'text/plain',
        pcdm_use: [Hyrax::FileMetadata::Use::ORIGINAL_FILE]
      ))
      file_set.file_ids = [original.id]
      Hyrax.persister.save(resource: file_set)
      index(file_set.id.to_s)
    end

    after { FileUtils.rm_rf(dir) }

    it 'indexes only what the file sets\' Solr documents hold and reads nothing from storage' do
      expect(all_text).to eq 'iiif print text'
      expect(reads).to be_empty
    end
  end

  context 'with a single PDF file set' do
    let(:member_ids) { [index('i295-pdf', ['pdf text'], **pdf)] }

    it 'indexes its text once' do
      expect(all_text).to eq 'pdf text'
    end
  end

  context 'with a PDF file set split into child works' do
    let(:member_ids) do
      [index('i295-pdf', ['pdf text'], **pdf),
       index('i295-child', ['page text'], 'has_model_ssim' => ['Book'], 'generic_type_sim' => ['Work'])]
    end

    it 'indexes the child works\' text instead of the PDF\'s' do
      expect(all_text).to eq 'page text'
    end
  end
end
