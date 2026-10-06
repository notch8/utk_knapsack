# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::MissingPdfText do
  let(:io) { StringIO.new }

  def save_file(file_set, use, mime_type, original_filename: nil)
    Hyrax.persister.save(resource: Hyrax::FileMetadata.new(file_set_id: file_set.id, mime_type:, pcdm_use: [use], original_filename:))
  end

  def create_file_set(mime_type:, texts: [], original_filename: nil, listed: true)
    file_set = Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ["#{mime_type} file set"]))
    original = save_file(file_set, Hyrax::FileMetadata::Use::ORIGINAL_FILE, mime_type, original_filename:)
    files = texts.map { |text_mime| save_file(file_set, Hyrax::FileMetadata::Use::EXTRACTED_TEXT, text_mime) }
    file_set.file_ids = (listed ? [original] : []).concat(files).map(&:id)
    Hyrax.persister.save(resource: file_set)
    original.id.to_s
  end

  let!(:pdf_without_text) { create_file_set(mime_type: 'application/pdf') }
  let!(:pdf_with_text) { create_file_set(mime_type: 'application/pdf', texts: ['text/plain']) }
  let!(:pdf_with_only_alto) { create_file_set(mime_type: 'application/pdf', texts: ['application/xml', 'application/json']) }
  let!(:uncharacterized_pdf) { create_file_set(mime_type: 'inode/x-empty', original_filename: 'memoir.pdf') }
  let!(:image) { create_file_set(mime_type: 'image/tiff') }
  let!(:unlisted_pdf) { create_file_set(mime_type: 'application/pdf', listed: false) }

  describe '#candidates' do
    subject(:ids) { described_class.new(io:).candidates.map { |original| original.id.to_s } }

    it 'includes a PDF with no plain-text derivative' do
      expect(ids).to include(pdf_without_text)
    end

    it 'includes a PDF whose only extracted text is ALTO and JSON' do
      expect(ids).to include(pdf_with_only_alto)
    end

    it 'includes a PDF known only by its filename' do
      expect(ids).to include(uncharacterized_pdf)
    end

    it 'skips a PDF that already has plain text' do
      expect(ids).not_to include(pdf_with_text)
    end

    it 'skips an image' do
      expect(ids).not_to include(image)
    end

    it 'skips an original its file set no longer lists' do
      expect(ids).not_to include(unlisted_pdf)
    end
  end

  describe '#call' do
    it 'enqueues one extraction job per candidate original and returns the count' do
      expect(described_class.call(io:)).to eq 3

      expect(HykuKnapsack::ExtractPdfTextJob).to have_been_enqueued.with(pdf_without_text)
      expect(HykuKnapsack::ExtractPdfTextJob).not_to have_been_enqueued.with(pdf_with_text)
      expect(io.string).to include('3 file sets enqueued')
    end

    it 'stops at the limit' do
      expect(described_class.call(io:, limit: 1)).to eq 1
      expect(HykuKnapsack::ExtractPdfTextJob).to have_been_enqueued.exactly(:once)
    end

    it 'enqueues nothing on a dry run but still lists the candidates' do
      described_class.call(io:, dry_run: true)

      expect(HykuKnapsack::ExtractPdfTextJob).not_to have_been_enqueued
      expect(io.string).to include(pdf_without_text).and include('3 file sets would be enqueued')
    end
  end
end
