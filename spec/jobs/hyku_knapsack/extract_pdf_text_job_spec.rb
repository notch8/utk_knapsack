# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::ExtractPdfTextJob do
  let(:file_set) { Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ['PDF file set'])) }
  let(:dir) do
    FileUtils.mkdir_p(Hyrax.config.derivatives_path)
    Pathname.new(Dir.mktmpdir(nil, Hyrax.config.derivatives_path))
  end
  let(:original) do
    path = dir.join('original.pdf').tap { |copy| FileUtils.cp(HykuKnapsack::Engine.root.join('spec/fixtures/pdfs/with_text.pdf'), copy) }
    Hyrax.persister.save(resource: Hyrax::FileMetadata.new(file_set_id: file_set.id, mime_type: 'application/pdf',
                                                           pcdm_use: [Hyrax::FileMetadata::Use::ORIGINAL_FILE],
                                                           file_identifier: Valkyrie::ID.new("disk://#{path}"))).tap do |file|
      Hyrax.persister.save(resource: file_set.tap { |fs| fs.file_ids += [file.id] })
    end
  end

  after { FileUtils.rm_rf(dir) }

  def texts
    reloaded = Hyrax.query_service.find_by(id: file_set.id)
    Hyrax.custom_queries.find_many_file_metadata_by_use(resource: reloaded, use: Hyrax::FileMetadata::Use::EXTRACTED_TEXT).to_a
  end

  it "saves the original's text as plain extracted text" do
    described_class.perform_now(original.id.to_s)

    expect(texts.map(&:mime_type)).to eq ['text/plain']
    expect(texts.first.file.read.strip).to eq 'Great Smoky Mountains'
  end

  it 'does not download the original when the text is already current' do
    described_class.perform_now(original.id.to_s)
    allow(Valkyrie::StorageAdapter).to receive(:adapter_for).and_call_original

    described_class.perform_now(original.id.to_s)

    expect(Valkyrie::StorageAdapter).not_to have_received(:adapter_for).with(id: original.file_identifier)
    expect(texts.size).to eq 1
  end

  it 'does not download an original removed from the file set after it was enqueued' do
    id = original.id.to_s
    Hyrax.persister.save(resource: Hyrax.query_service.find_by(id: file_set.id).tap { |fs| fs.file_ids -= [original.id] })
    allow(Valkyrie::StorageAdapter).to receive(:adapter_for).and_call_original

    described_class.perform_now(id)

    expect(Valkyrie::StorageAdapter).not_to have_received(:adapter_for).with(id: original.file_identifier)
    expect(texts).to be_empty
  end
end
