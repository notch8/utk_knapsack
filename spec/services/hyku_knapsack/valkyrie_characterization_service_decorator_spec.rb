# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::ValkyrieCharacterizationServiceDecorator do
  let(:metadata) { Hyrax::FileMetadata.new(original_filename: 'page.jp2') }
  let(:characterizer) { double(characterize: fits) }

  def identity(format, mimetype, *tools)
    tags = tools.map { |tool| %(<tool toolname="#{tool}" toolversion="1"/>) }.join
    %(<identity format="#{format}" mimetype="#{mimetype}">#{tags}</identity>)
  end

  def fits_with(status, *identities)
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <fits xmlns="http://hul.harvard.edu/ois/xml/ns/fits/fits_output" version="1.5.0">
        <identification status="#{status}">#{identities.join}</identification>
      </fits>
    XML
  end

  before do
    Hyrax::Characterization::ValkyrieCharacterizationService
      .new(metadata:, file: StringIO.new('bytes'), characterizer:).characterize
  end

  context 'when most tools disagree with one outlier' do
    let(:fits) do
      fits_with('CONFLICT',
                identity('JPEG 2000 JP2', 'image/jp2', 'Droid', 'Jhove', 'file utility', 'Exiftool', 'Tika'),
                identity('Microsoft Excel', 'application/vnd.ms-excel', 'ffident'))
    end

    it "stores the majority's identity" do
      expect(metadata).to have_attributes(mime_type: 'image/jp2', format_label: ['JPEG 2000 JP2'])
    end
  end

  context 'when the majority is listed last' do
    let(:fits) do
      fits_with('CONFLICT',
                identity('Algol 68 source', 'text/x-Algol68', 'file utility'),
                identity('Plain text', 'text/plain', 'Droid', 'Jhove', 'Tika'))
    end

    it 'counts tools rather than trusting order' do
      expect(metadata).to have_attributes(mime_type: 'text/plain', format_label: ['Plain text'])
    end
  end

  context 'when the majority MIME type is split across identities' do
    let(:fits) do
      fits_with('CONFLICT',
                identity('Microsoft Excel', 'application/vnd.ms-excel', 'ffident', 'Tika', 'file utility'),
                identity('JPEG 2000 JP2', 'image/jp2', 'Droid', 'Jhove'),
                identity('JPEG 2000', 'image/jp2', 'Exiftool', 'jpylyzer'))
    end

    it 'counts tools per MIME type' do
      expect(metadata).to have_attributes(mime_type: 'image/jp2', format_label: ['JPEG 2000 JP2', 'JPEG 2000'])
    end
  end

  context 'when the tools tie' do
    let(:fits) do
      fits_with('CONFLICT',
                identity('TIFF', 'image/tiff', 'Exiftool'),
                identity('Microsoft Excel', 'application/vnd.ms-excel', 'ffident'))
    end

    it 'keeps the identity FITS lists first' do
      expect(metadata).to have_attributes(mime_type: 'image/tiff', format_label: ['TIFF'])
    end
  end

  context 'without a conflict' do
    let(:fits) do
      fits_with('SINGLE_RESULT',
                identity('TIFF EXIF', 'image/tiff', 'Exiftool'),
                identity('Tagged Image File Format', 'image/x-tiff', 'Droid'))
    end

    it 'leaves the identities as Hyrax reads them' do
      expect(metadata).to have_attributes(mime_type: 'image/x-tiff',
                                          format_label: ['TIFF EXIF', 'Tagged Image File Format'])
    end
  end
end
