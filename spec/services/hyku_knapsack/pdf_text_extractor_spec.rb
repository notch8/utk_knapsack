# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::PdfTextExtractor do
  let(:fixtures) { HykuKnapsack::Engine.root.join('spec/fixtures/pdfs') }
  let(:file_set) { Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ['PDF file set'])) }

  def reloaded
    Hyrax.query_service.find_by(id: file_set.id)
  end

  def texts
    Hyrax.custom_queries.find_many_file_metadata_by_use(resource: reloaded, use: Hyrax::FileMetadata::Use::EXTRACTED_TEXT).to_a
  end

  let(:dir) do
    FileUtils.mkdir_p(Hyrax.config.derivatives_path)
    Pathname.new(Dir.mktmpdir(nil, Hyrax.config.derivatives_path))
  end

  after { FileUtils.rm_rf(dir) }

  def attach(use, mime_type, source = fixtures.join('portrait.pdf'))
    path = dir.join(SecureRandom.uuid).tap { |copy| FileUtils.cp(source, copy) }
    Hyrax.persister.save(resource: Hyrax::FileMetadata.new(file_set_id: file_set.id, mime_type:, pcdm_use: [use],
                                                           file_identifier: Valkyrie::ID.new("disk://#{path}"))).tap do |file|
      Hyrax.persister.save(resource: reloaded.tap { |fs| fs.file_ids += [file.id] })
    end
  end

  def attach_text(mime_type = 'text/plain')
    attach(Hyrax::FileMetadata::Use::EXTRACTED_TEXT, mime_type)
  end

  def attach_original
    attach(Hyrax::FileMetadata::Use::ORIGINAL_FILE, 'application/pdf')
  end

  def extract(original, pdf = 'with_text.pdf')
    described_class.call(file_set: reloaded, path: fixtures.join(pdf), original:)
  end

  it "saves the PDF's text as plain extracted text and reindexes the file set" do
    allow(Hyrax.publisher).to receive(:publish).and_call_original

    extract(attach_original)

    expect(texts.map(&:mime_type)).to eq ['text/plain']
    expect(texts.first.file.read.strip).to eq 'Great Smoky Mountains'
    expect(Hyrax.publisher).to have_received(:publish).with('object.membership.updated', hash_including(object: anything))
  end

  it 'leaves plain text attached after the original, such as the legacy txt' do
    original = attach_original
    attach_text
    allow(Open3).to receive(:capture3).and_call_original

    extract(original)

    expect(Open3).not_to have_received(:capture3)
    expect(texts.size).to eq 1
  end

  it 'replaces text extracted from an earlier original uploaded beside it' do
    attach_original
    attach_text
    replacement = attach_original

    extract(replacement)

    expect(texts.size).to eq 1
    expect(texts.first.file.read.strip).to eq 'Great Smoky Mountains'
    expect(texts.first.created_at).to be > replacement.created_at
  end

  it 'drops the earlier text and reindexes when the new original has no text layer' do
    attach_original
    attach_text
    replacement = attach_original
    allow(Hyrax.publisher).to receive(:publish).and_call_original

    extract(replacement, 'portrait.pdf')

    expect(texts).to be_empty
    expect(Hyrax.publisher).to have_received(:publish).with('object.membership.updated', hash_including(object: anything))
  end

  it 'leaves the replacement alone when a delayed job for the earlier original runs last' do
    earlier = attach_original
    attach_original
    allow(Open3).to receive(:capture3).and_call_original

    extract(earlier)

    expect(Open3).not_to have_received(:capture3)
    expect(texts).to be_empty
  end

  it 'leaves the file set alone when the original was replaced while pdftotext ran' do
    earlier = attach_original
    allow(described_class).to receive(:pdftotext).and_wrap_original do |method, *args|
      attach_original
      method.call(*args)
    end

    extract(earlier)

    expect(texts).to be_empty
  end

  it 'does nothing for an original the file set no longer lists' do
    original = attach_original
    Hyrax.persister.save(resource: reloaded.tap { |fs| fs.file_ids -= [original.id] })

    expect(described_class.needed?(reloaded, original:)).to be false
  end

  it 'still extracts when the only extracted text is ALTO' do
    original = attach_original
    attach_text('application/xml')

    expect(described_class.needed?(reloaded, original:)).to be true
  end

  it 'saves nothing for a PDF with no text layer' do
    extract(attach_original, 'portrait.pdf')

    expect(texts).to be_empty
  end

  it 'saves nothing when pdftotext cannot read the file' do
    described_class.call(file_set: reloaded, path: __FILE__, original: attach_original)

    expect(texts).to be_empty
  end
end
