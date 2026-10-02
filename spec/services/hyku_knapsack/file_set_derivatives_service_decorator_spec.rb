# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::FileSetDerivativesServiceDecorator do
  let(:file_set) { Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ['Derivatives'])) }
  let(:path) { HykuKnapsack::Engine.root.join('spec/fixtures/pdfs/with_text.pdf').to_s }

  def original(mime_type)
    Hyrax::FileMetadata.new(file_set_id: file_set.id, mime_type:, pcdm_use: [Hyrax::FileMetadata::Use::ORIGINAL_FILE])
  end

  before do
    allow(Hydra::Derivatives::PdfDerivatives).to receive(:create)
    allow(Hydra::Derivatives::ImageDerivatives).to receive(:create)
    allow(HykuKnapsack::PdfTextExtractor).to receive(:call)
  end

  it "extracts a PDF's text from the file the job already downloaded, after its thumbnail" do
    pdf = original('application/pdf')
    Hyrax::FileSetDerivativesService.new(pdf).create_derivatives(path)

    expect(Hydra::Derivatives::PdfDerivatives).to have_received(:create).ordered
    expect(HykuKnapsack::PdfTextExtractor).to have_received(:call)
      .with(file_set: having_attributes(id: file_set.id), path:, original: pdf).ordered
  end

  it 'extracts nothing for an image' do
    Hyrax::FileSetDerivativesService.new(original('image/tiff')).create_derivatives(path)

    expect(HykuKnapsack::PdfTextExtractor).not_to have_received(:call)
  end
end
