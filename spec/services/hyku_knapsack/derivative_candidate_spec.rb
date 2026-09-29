# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::DerivativeCandidate do
  describe '.match?' do
    let(:service_file) { Hyrax::FileSet.new(rdf_type: ['http://pcdm.org/use#ServiceFile']) }
    let(:intermediate) { Hyrax::FileSet.new(rdf_type: ['http://pcdm.org/use#IntermediateFile']) }

    it 'accepts any PDF' do
      expect(described_class.match?(service_file, Hyrax::FileMetadata.new(mime_type: 'application/pdf'))).to be true
    end

    it 'accepts a PDF by filename when legacy recorded no useful mime type' do
      empty = Hyrax::FileMetadata.new(mime_type: 'inode/x-empty', original_filename: '50yrcove1176_fileset.pdf')

      expect(described_class.match?(service_file, empty)).to be true
    end

    it 'accepts a PDF by filename regardless of case' do
      shouty = Hyrax::FileMetadata.new(mime_type: 'application/octet-stream', original_filename: 'REPORT.PDF')

      expect(described_class.match?(service_file, shouty)).to be true
    end

    it 'rejects a file whose name only mentions pdf' do
      notes = Hyrax::FileMetadata.new(mime_type: 'text/plain', original_filename: 'pdf_notes.txt')

      expect(described_class.match?(service_file, notes)).to be false
    end

    it 'rejects a non-PDF with no filename' do
      expect(described_class.match?(service_file, Hyrax::FileMetadata.new(mime_type: 'image/tiff'))).to be false
    end

    it 'accepts an intermediate file of any type, audio included' do
      expect(described_class.match?(intermediate, Hyrax::FileMetadata.new(mime_type: 'audio/mpeg'))).to be true
    end

    it 'rejects a preservation master that is not intermediate' do
      preservation = Hyrax::FileSet.new(rdf_type: ['http://pcdm.org/use#PreservationFile'])

      expect(described_class.match?(preservation, Hyrax::FileMetadata.new(mime_type: 'image/tiff'))).to be false
    end
  end
end
