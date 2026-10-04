# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'IIIF manifest configuration' do
  it 'points the viewer at the knapsack UV config, which labels the rights row' do
    expect(IiifPrint.config.uv_config_path).to eq '/uv/knapsack-uv-config.json'
    expect(HykuKnapsack::Engine.root.join('public', 'uv', 'knapsack-uv-config.json')).to exist
  end
end
