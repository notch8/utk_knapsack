# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0: save a PDF's text as its extracted text derivative, from the copy the
# derivatives job already downloaded
module HykuKnapsack
  module FileSetDerivativesServiceDecorator
    private

    def create_pdf_derivatives(filename)
      super
      HykuKnapsack::PdfTextExtractor.call(file_set: Hyrax.query_service.find_by(id: uri), path: filename, original: file_set)
    end
  end
end

Hyrax::FileSetDerivativesService.prepend(HykuKnapsack::FileSetDerivativesServiceDecorator)
