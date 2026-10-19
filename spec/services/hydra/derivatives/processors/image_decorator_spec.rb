# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hydra::Derivatives::Processors::ImageDecorator do
  let(:jp2) { fixture_file_path('hyrax/image.jp2').to_s }
  let(:thumbnail) { Hyrax.config.derivative_options[:image].find { |output| output[:label] == :thumbnail } }
  let(:max_width) { thumbnail[:size][/\A\d+/].to_i }
  let(:max_height) { thumbnail[:size][/x(\d+)/, 1].to_i }
  let(:written) { StringIO.new }
  let(:output) { ->(io, _directives) { written.write(io.read) } }
  let(:collect_garbage_before_resizing) do
    Module.new do
      def size
        GC.start(full_mark: true, immediate_sweep: true)
        super
      end
    end
  end

  def thumbnail_dimensions_for(path)
    processor = Hydra::Derivatives::Processors::Image.new(path, thumbnail, output_file_service: output)
    processor.extend(collect_garbage_before_resizing)
    processor.process
    MiniMagick::Image.read(written.string).dimensions
  end

  it 'makes a JP2 thumbnail at the configured size when garbage collection runs mid-conversion' do
    width, height = thumbnail_dimensions_for(jp2)

    expect([width, height]).to satisfy { width <= max_width && height <= max_height && (width == max_width || height == max_height) }
  end

  it 'makes a TIFF thumbnail at the configured size when garbage collection runs mid-conversion' do
    Dir.mktmpdir do |dir|
      tiff = File.join(dir, 'image.tif')
      MiniMagick::Tool::Convert.new { |convert| convert << jp2 << tiff }

      width, height = thumbnail_dimensions_for(tiff)

      expect([width, height]).to satisfy { width <= max_width && height <= max_height && (width == max_width || height == max_height) }
    end
  end
end
