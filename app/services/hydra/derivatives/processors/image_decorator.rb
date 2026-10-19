# frozen_string_literal: true

# OVERRIDE Hydra::Derivatives 4.1.0: hold the opened source image until the conversion finishes, so
# garbage collection cannot delete the temp file a selected layer still reads from
module Hydra
  module Derivatives
    module Processors
      module ImageDecorator
        private

        def selected_layers(image)
          @source_image = image
          super
        end
      end
    end
  end
end

Hydra::Derivatives::Processors::Image.prepend(Hydra::Derivatives::Processors::ImageDecorator)
