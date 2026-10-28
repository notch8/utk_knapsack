# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'config/initializers/hydra_derivatives.rb' do
  let(:codec) { Hydra::Derivatives::Processors::Video::Processor.config.mpeg4.codec }

  it 'encodes mp4 video derivatives with the veryfast x264 preset' do
    expect(codec).to end_with ' -preset veryfast'
  end

  it 'adds the preset once, though the knapsack loads its initializers twice' do
    expect(codec.scan('-preset').size).to eq 1
  end

  it 'hands ffmpeg a quality target and a front-loaded index for the configured mp4 output' do
    directives = Hyrax.config.derivative_options[:video].find { |output| output[:label] == 'mp4' }
    processor = Hydra::Derivatives::Processors::Video::Processor.new('in.mp4', directives.merge(size: '320x240'))
    options = processor.send(:options_for, 'mp4')[Hydra::Derivatives::Processors::Ffmpeg::OUTPUT_OPTIONS]

    expect(options).to include('-crf 23', '-movflags +faststart')
    expect(options).not_to include('-b:v')
  end
end
