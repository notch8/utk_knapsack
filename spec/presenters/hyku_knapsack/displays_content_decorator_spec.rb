# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::DisplaysContentDecorator do
  subject(:content) { presenter.display_content }

  let(:presenter) do
    Hyrax::IiifManifestPresenter::DisplayImagePresenter.new(
      SolrDocument.new(id: 'abc123', has_model_ssim: ['Hyrax::FileSet'], mime_type_ssi: 'audio/wav')
    ).tap { |p| p.hostname = 'example.com' }
  end

  before { allow(Flipflop).to receive(:iiif_av?).and_return(true) }

  it 'gives the audio canvas the fingerprinted audio thumbnail' do
    expect(content.thumbnail.first[:id]).to match %r{\Ahttp://example\.com/assets/audio-\h+\.png\z}
  end
end
