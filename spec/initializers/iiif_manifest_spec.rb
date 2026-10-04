# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'IIIF manifest configuration' do
  it 'points the viewer at the knapsack UV config, which labels the rights row' do
    expect(IiifPrint.config.uv_config_path).to eq '/uv/knapsack-uv-config.json'
    expect(HykuKnapsack::Engine.root.join('public', 'uv', 'knapsack-uv-config.json')).to exist
  end

  it 'leaves the top-level rights out of manifests, since the rights statement is already a metadata row' do
    presenter = Hyrax::IiifManifestPresenter.new(
      SolrDocument.new(id: 'w1', has_model_ssim: ['Book'], rights_statement_tesim: ['http://rightsstatements.org/vocab/InC/1.0/'])
    )

    expect(IIIFManifest.config.manifest_value_for(presenter, property: :rights)).to be_nil
  end
end
