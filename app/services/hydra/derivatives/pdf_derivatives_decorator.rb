# frozen_string_literal: true

# OVERRIDE Hydra::Derivatives 4.1.0: render PDF thumbnails at their target size with libvips
module Hydra
  module Derivatives
    module PdfDerivativesDecorator
      def processor_class
        HykuKnapsack::PdfThumbnailProcessor
      end
    end
  end
end

Hydra::Derivatives::PdfDerivatives.singleton_class.prepend(Hydra::Derivatives::PdfDerivativesDecorator)
