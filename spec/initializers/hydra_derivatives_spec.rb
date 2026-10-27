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
end
