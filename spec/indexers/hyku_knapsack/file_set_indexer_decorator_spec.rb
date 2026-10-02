# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::FileSetIndexerDecorator do
  subject(:solr_doc) { Hyku::Indexers::FileSetIndexer.new(resource: file_set).to_solr }

  let(:dir) do
    FileUtils.mkdir_p(Hyrax.config.derivatives_path)
    Pathname.new(Dir.mktmpdir(nil, Hyrax.config.derivatives_path))
  end
  let(:file_set) { Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ['PDF file set'])) }
  let(:reads) { [] }

  after { FileUtils.rm_rf(dir) }

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

  def attach(use, path, mime_type)
    Hyrax.persister.save(resource: Hyrax::FileMetadata.new(file_identifier: Valkyrie::ID.new("disk://#{path}"),
                                                           file_set_id: file_set.id, mime_type:, pcdm_use: [use]))
  end

  def link(*files)
    file_set.file_ids = files.map(&:id)
    Hyrax.persister.save(resource: file_set)
  end

  def write(name, content)
    dir.join(name).tap { |path| File.binwrite(path, content) }
  end

  let(:original) do
    attach(Hyrax::FileMetadata::Use::ORIGINAL_FILE, write('original.pdf', '%PDF-1.4'), 'application/pdf')
  end

  context 'when the PDF has an extracted text derivative' do
    let(:text) { attach(Hyrax::FileMetadata::Use::EXTRACTED_TEXT, write('txt.txt', "Café on the\nFrench Broad"), 'text/plain') }

    before { link(original, text) }

    it 'indexes the derivative without reading the original' do
      expect(solr_doc['all_text_tsimv']).to eq 'Café on the French Broad'
      expect(solr_doc['all_text_timv']).to eq 'Café on the French Broad'
      expect(reads).to eq [text.file_identifier.to_s]
    end
  end

  context 'when the PDF also has ALTO filed as extracted text' do
    before do
      alto = attach(Hyrax::FileMetadata::Use::EXTRACTED_TEXT, write('xml.xml', '<alto>markup</alto>'), 'application/xml')
      link(original, alto, attach(Hyrax::FileMetadata::Use::EXTRACTED_TEXT, write('txt.txt', 'plain text'), 'text/plain'))
    end

    it 'indexes the plain text' do
      expect(solr_doc['all_text_tsimv']).to eq 'plain text'
    end
  end

  context 'when the PDF has no extracted text derivative' do
    before { link(original) }

    it 'indexes no text and never reads the original' do
      expect(solr_doc['all_text_tsimv']).to be_nil
      expect(reads).to be_empty
    end
  end

  context 'when the extracted text derivative is missing from storage' do
    before { link(original, attach(Hyrax::FileMetadata::Use::EXTRACTED_TEXT, dir.join('gone.txt'), 'text/plain')) }

    it 'indexes no text rather than failing the reindex' do
      expect(solr_doc['all_text_tsimv']).to be_nil
    end
  end

  context 'when the file set is not a PDF' do
    let(:image) { attach(Hyrax::FileMetadata::Use::ORIGINAL_FILE, write('page.tif', 'tiff bytes'), 'image/tiff') }

    before { link(image, attach(Hyrax::FileMetadata::Use::EXTRACTED_TEXT, write('txt.txt', 'page text'), 'text/plain')) }

    it 'keeps the text iiif_print indexes and never reads the original' do
      expect(solr_doc['all_text_tsimv']).to eq 'page text'
      expect(reads).not_to include(image.file_identifier.to_s)
    end
  end
end
