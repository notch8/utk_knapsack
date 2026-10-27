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

  describe 'Compound Object viewer default' do
    subject(:presenter) { described_class.new(SolrDocument.new(document), instance_double(Ability), nil) }

    let(:representative) { double('file_set_presenter', audio?: false, video?: false) }

    before do
      allow(presenter).to receive_messages(representative_id: 'fs1', representative_presenter: representative)
    end

    after do
      test_strategy.switch!(:per_work_media_viewer,
                            Flipflop::FeatureSet.current.feature(:per_work_media_viewer).default)
    end

    [true, false].each do |enabled|
      context "with per_work_media_viewer #{enabled ? 'on' : 'off'}" do
        before { test_strategy.switch!(:per_work_media_viewer, enabled) }

        context 'when no viewer is set' do
          let(:document) { { 'has_model_ssim' => ['CompoundObject'] } }

          it 'opens in Clover' do
            expect(presenter.iiif_viewer).to eq(:clover)
          end
        end

        context 'when no viewer is set and nothing is IIIF-viewable' do
          let(:document) { { 'has_model_ssim' => ['CompoundObject'] } }
          let(:representative) { double('file_set_presenter', image?: false, audio?: false, video?: false, pdf?: false) }

          it 'shows no IIIF viewer' do
            expect(presenter.iiif_viewer?).to be(false)
          end
        end
      end
    end

    context 'when a viewer is set' do
      let(:document) { { 'has_model_ssim' => ['CompoundObject'], 'media_viewer_ssi' => 'universal_viewer' } }

      before { test_strategy.switch!(:per_work_media_viewer, true) }

      it 'keeps the chosen viewer' do
        expect(presenter.iiif_viewer).to eq(:universal_viewer)
      end
    end

    context 'when the work is not a Compound Object' do
      let(:document) { { 'has_model_ssim' => ['StillImage'] } }

      it 'leaves the default alone' do
        expect(presenter.iiif_viewer).not_to eq(:clover)
      end
    end
  end
end
