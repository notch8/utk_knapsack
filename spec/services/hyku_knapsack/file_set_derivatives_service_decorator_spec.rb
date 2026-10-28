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

  context 'with audio and video' do
    let(:av_path) { HykuKnapsack::Engine.root.join('spec/fixtures/av', fixture).to_s }
    let(:fixture) { 'h264.mp4' }

    def labels(processor)
      outputs = nil
      expect(processor).to have_received(:create) { |_, options| outputs = options[:outputs] }
      outputs.map { |output| output[:label].to_s }
    end

    before do
      allow(Hydra::Derivatives::AudioDerivatives).to receive(:create)
      allow(Hydra::Derivatives::VideoDerivatives).to receive(:create)
    end

    it 'makes only a thumbnail for an H.264 MP4' do
      Hyrax::FileSetDerivativesService.new(original('video/mp4')).create_derivatives(av_path)

      expect(labels(Hydra::Derivatives::VideoDerivatives)).to eq %w[thumbnail]
    end

    context 'with an MP4 a browser cannot play' do
      let(:fixture) { 'mpeg4.mp4' }

      it 'makes a thumbnail and an mp4 service file' do
        Hyrax::FileSetDerivativesService.new(original('video/mp4')).create_derivatives(av_path)

        expect(labels(Hydra::Derivatives::VideoDerivatives)).to eq %w[thumbnail mp4]
      end
    end

    it 'makes a thumbnail and an mp4 service file for a QuickTime original' do
      Hyrax::FileSetDerivativesService.new(original('video/quicktime')).create_derivatives(av_path)

      expect(labels(Hydra::Derivatives::VideoDerivatives)).to eq %w[thumbnail mp4]
    end

    context 'with an MP3' do
      let(:fixture) { 'mp3.mp3' }

      it 'makes nothing' do
        Hyrax::FileSetDerivativesService.new(original('audio/mpeg')).create_derivatives(av_path)

        expect(Hydra::Derivatives::AudioDerivatives).not_to have_received(:create)
      end
    end

    it 'makes an mp3 service file for a WAV' do
      Hyrax::FileSetDerivativesService.new(original('audio/x-wav')).create_derivatives(av_path)

      expect(labels(Hydra::Derivatives::AudioDerivatives)).to eq %w[mp3]
    end
  end
end
