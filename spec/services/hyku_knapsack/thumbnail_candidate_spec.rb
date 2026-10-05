# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::ThumbnailCandidate do
  describe '.match?' do
    let(:service_file) { Hyrax::FileSet.new(rdf_type: ['http://pcdm.org/use#ServiceFile']) }
    let(:intermediate) { Hyrax::FileSet.new(rdf_type: ['http://pcdm.org/use#IntermediateFile']) }
    let(:tiff) { Hyrax::FileMetadata.new(mime_type: 'image/tiff') }

    it 'accepts any PDF' do
      expect(described_class.match?(service_file, Hyrax::FileMetadata.new(mime_type: 'application/pdf'))).to be true
    end

    it 'accepts a PDF known only by its filename' do
      empty = Hyrax::FileMetadata.new(mime_type: 'inode/x-empty', original_filename: 'report.pdf')

      expect(described_class.match?(service_file, empty)).to be true
    end

    it 'accepts an intermediate image' do
      expect(described_class.match?(intermediate, tiff)).to be true
    end

    it 'rejects an intermediate audio file, whose derivatives are mp3 and ogg with no thumbnail' do
      expect(described_class.match?(intermediate, Hyrax::FileMetadata.new(mime_type: 'audio/mpeg'))).to be false
    end

    it 'rejects a preservation master that is not intermediate' do
      expect(described_class.match?(Hyrax::FileSet.new(rdf_type: ['http://pcdm.org/use#PreservationFile']), tiff)).to be false
    end

    it 'rejects a metadata record' do
      xml = Hyrax::FileMetadata.new(mime_type: 'text/xml')

      expect(described_class.match?(Hyrax::FileSet.new(rdf_type: ['http://pcdm.org/file-format-types#Markup']), xml)).to be false
    end
  end
end
