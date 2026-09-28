# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::MissingThumbnails do
  let(:io) { StringIO.new }
  def save_file(file_set, use, mime_type, original_filename: nil)
    Hyrax.persister.save(resource: Hyrax::FileMetadata.new(file_set_id: file_set.id, mime_type:, pcdm_use: [use], original_filename:))
  end

  def create_file_set(rdf_type:, mime_type:, thumbnail:, extracted_text: false, original_filename: nil)
    file_set = Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ["#{mime_type} file set"], rdf_type:))
    files = []
    files << save_file(file_set, Hyrax::FileMetadata::Use::EXTRACTED_TEXT, 'text/plain') if extracted_text
    original = save_file(file_set, Hyrax::FileMetadata::Use::ORIGINAL_FILE, mime_type, original_filename:)
    files << original
    files.unshift(save_file(file_set, Hyrax::FileMetadata::Use::THUMBNAIL_IMAGE, 'image/jpeg')) if thumbnail
    file_set.file_ids = files.map(&:id)
    Hyrax.persister.save(resource: file_set)
    [file_set.id.to_s, original.id.to_s]
  end
  let!(:pdf_without_thumbnail) do
    create_file_set(rdf_type: ['http://pcdm.org/file-format-types#Document', 'http://pcdm.org/use#ServiceFile'],
                    mime_type: 'application/pdf', thumbnail: false)
  end
  let!(:pdf_with_thumbnail) do
    create_file_set(rdf_type: ['http://pcdm.org/file-format-types#Document', 'http://pcdm.org/use#ServiceFile'],
                    mime_type: 'application/pdf', thumbnail: true)
  end
  let!(:intermediate_tiff_without_thumbnail) do
    create_file_set(rdf_type: ['http://pcdm.org/use#PreservationFile', 'http://pcdm.org/use#IntermediateFile'],
                    mime_type: 'image/tiff', thumbnail: false)
  end
  let!(:preservation_tiff_without_thumbnail) do
    create_file_set(rdf_type: ['http://pcdm.org/use#PreservationFile'], mime_type: 'image/tiff', thumbnail: false)
  end
  let!(:uncharacterized_pdf) do
    create_file_set(rdf_type: ['http://pcdm.org/use#ServiceFile'], mime_type: 'inode/x-empty', thumbnail: false,
                    original_filename: '50yrcove1176_fileset.pdf')
  end
  let!(:mods_without_thumbnail) do
    create_file_set(rdf_type: ['http://pcdm.org/file-format-types#Markup'], mime_type: 'text/xml', thumbnail: false)
  end

  describe '#candidates' do
    subject(:ids) { described_class.new(io:).candidates.map(&:file_set_id) }

    it 'includes a PDF with no thumbnail' do
      expect(ids).to include(pdf_without_thumbnail.first)
    end

    it 'includes an IntermediateFile with no thumbnail' do
      expect(ids).to include(intermediate_tiff_without_thumbnail.first)
    end

    it 'skips a PDF that already has a thumbnail' do
      expect(ids).not_to include(pdf_with_thumbnail.first)
    end

    it 'skips a preservation master that is not intermediate' do
      expect(ids).not_to include(preservation_tiff_without_thumbnail.first)
    end

    it 'skips a MODS record' do
      expect(ids).not_to include(mods_without_thumbnail.first)
    end

    it 'skips a file set with no files at all' do
      empty = Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ['empty']))

      expect(ids).not_to include(empty.id.to_s)
    end

    it 'pairs each candidate with its original file' do
      candidate = described_class.new(io:).candidates.find { |c| c.file_set_id == pdf_without_thumbnail.first }

      expect(candidate.original.id.to_s).to eq(pdf_without_thumbnail.last)
    end

    it 'finds the original by use when another file is listed before it' do
      file_set_id, original_id = create_file_set(rdf_type: ['http://pcdm.org/use#IntermediateFile'], mime_type: 'image/tiff',
                                                 thumbnail: false, extracted_text: true)

      candidate = described_class.new(io:).candidates.find { |c| c.file_set_id == file_set_id }

      expect(candidate.original.id.to_s).to eq(original_id)
    end
  end

  describe '#call' do
    it 'enqueues one derivative job per candidate with the file set and original ids' do
      described_class.call(io:)

      expect(ValkyrieCreateDerivativesJob).to have_been_enqueued.with(*pdf_without_thumbnail)
      expect(ValkyrieCreateDerivativesJob).to have_been_enqueued.with(*intermediate_tiff_without_thumbnail)
      expect(ValkyrieCreateDerivativesJob).not_to have_been_enqueued.with(*pdf_with_thumbnail)
    end

    it 'returns the number enqueued and reports a tally by mime type' do
      expect(described_class.call(io:)).to eq(3)
      expect(io.string).to include('3 file sets enqueued').and include('application/pdf=1').and include('image/tiff=1')
    end

    it 'sends a PDF Hyrax has no derivative service for to characterization first, which chains the thumbnail' do
      described_class.call(io:)

      expect(UtkMigrationCharacterizationJob).to have_been_enqueued.with(uncharacterized_pdf.last)
      expect(ValkyrieCreateDerivativesJob).not_to have_been_enqueued.with(*uncharacterized_pdf)
      expect(io.string).to include("#{uncharacterized_pdf.first} inode/x-empty characterize first")
    end

    it 'enqueues nothing on a dry run but still lists the candidates' do
      described_class.call(io:, dry_run: true)

      expect(ValkyrieCreateDerivativesJob).not_to have_been_enqueued
      expect(io.string).to include(pdf_without_thumbnail.first).and include('3 file sets would be enqueued')
    end

    it 'reads the service list the way the engine registers it on a Hyrax without the config accessor' do
      allow(Hyrax.config).to receive(:respond_to?).and_call_original
      allow(Hyrax.config).to receive(:respond_to?).with(:derivative_services).and_return(false)
      allow(Hyrax::DerivativeService).to receive(:services).and_return([Hyrax::FileSetDerivativesService])

      described_class.call(io:)

      expect(Hyrax::DerivativeService).to have_received(:services).at_least(:once)
      expect(UtkMigrationCharacterizationJob).to have_been_enqueued.with(uncharacterized_pdf.last)
      expect(ValkyrieCreateDerivativesJob).to have_been_enqueued.with(*pdf_without_thumbnail)
    end

    it 'stops at the limit' do
      expect { expect(described_class.call(io:, limit: 1)).to eq(1) }.to have_enqueued_job.exactly(1).times
    end

    it 'enqueues nothing when the limit is zero' do
      expect(described_class.call(io:, limit: 0)).to eq(0)
      expect(ValkyrieCreateDerivativesJob).not_to have_been_enqueued
    end

    it 'finds nothing to do once every candidate has a thumbnail' do
      [pdf_without_thumbnail, intermediate_tiff_without_thumbnail, uncharacterized_pdf].each do |file_set_id, _|
        file_set = Hyrax.query_service.find_by(id: file_set_id)
        thumbnail = save_file(file_set, Hyrax::FileMetadata::Use::THUMBNAIL_IMAGE, 'image/jpeg')
        file_set.file_ids += [thumbnail.id]
        Hyrax.persister.save(resource: file_set)
      end

      expect(described_class.call(io:)).to eq(0)
      expect(ValkyrieCreateDerivativesJob).not_to have_been_enqueued
    end
  end
end
