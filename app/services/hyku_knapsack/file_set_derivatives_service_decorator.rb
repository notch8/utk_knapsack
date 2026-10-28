# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0: save a PDF's text as its extracted text derivative, from the copy the
# derivatives job already downloaded, and make no audio or video service file for an original a
# browser already plays
module HykuKnapsack
  module FileSetDerivativesServiceDecorator
    private

    def create_pdf_derivatives(filename)
      super
      HykuKnapsack::PdfTextExtractor.call(file_set: Hyrax.query_service.find_by(id: uri), path: filename, original: file_set)
    end

    def create_audio_derivatives(filename)
      super unless WebPlayable.match?(mime_type, filename)
    end

    def create_video_derivatives(filename)
      return super unless WebPlayable.match?(mime_type, filename)

      Hydra::Derivatives::VideoDerivatives.create(filename, outputs: thumbnail_outputs)
    end

    def thumbnail_outputs
      derivative_outputs(:video).reject { |output| output[:container] == 'service_file' }
    end
  end
end

Hyrax::FileSetDerivativesService.prepend(HykuKnapsack::FileSetDerivativesServiceDecorator)
