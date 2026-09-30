# frozen_string_literal: true

module HykuKnapsack
  class PdfThumbnailProcessor < Hydra::Derivatives::Processors::Image
    SIZE_OPTIONS = { '>' => :down, '<' => :up, '!' => :force }.freeze

    protected

    def create_resized_image
      width, height, flag = size.match(/(\d+)x(\d+)(.)?/).captures
      image = Vips::Image.thumbnail("#{source_path}[page=#{directives.fetch(:layer, 0)}]", width.to_i,
                                    height: height.to_i, size: SIZE_OPTIONS.fetch(flag, :both))
      write_image_with_vips(image, directives)
    end
  end
end
