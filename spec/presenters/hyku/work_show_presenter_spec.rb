# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyku::WorkShowPresenter do
  subject(:presenter) { described_class.new(SolrDocument.new({}), instance_double(Ability), nil) }

  let!(:test_strategy) { Flipflop::FeatureSet.current.test! }

  before { test_strategy.switch!(:iiif_av, true) }
  after { test_strategy.switch!(:iiif_av, Flipflop::FeatureSet.current.feature(:iiif_av).default) }

  %i[audio? video?].each do |media|
    it "opens a work whose representative answers #{media} in Clover" do
      representative = double('file_set_presenter', audio?: false, video?: false, media => true)
      allow(presenter).to receive(:representative_presenter).and_return(representative)

      expect(presenter.iiif_viewer).to eq(:clover)
    end
  end
end
