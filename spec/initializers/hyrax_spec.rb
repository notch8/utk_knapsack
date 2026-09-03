# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'config/initializers/hyrax.rb' do
  let(:registered) { Hyrax.config.registered_curation_concern_types }

  it 'registers the UTK work types' do
    expect(registered).to eq %w[StillImage Audio Book CompoundObject Newspaper Pdf Video]
  end

  it "unregisters the host application's stock work types" do
    expect(registered).not_to include('GenericWork', 'Image', 'Etd', 'Oer')
  end

  it 'points Bulkrax at a registered work type' do
    expect(registered).to include(Bulkrax::Entry.default_work_type)
  end

  it 'assigns the Bulkrax default from to_prepare, before eager load snapshots it' do
    path = HykuKnapsack::Engine.root.join('config', 'initializers', 'hyrax.rb').to_s
    block = Rails.application.config.to_prepare_blocks.find { |b| b.source_location.first == path }
    Bulkrax.default_work_type = 'Sentinel'

    expect { block.call }.to change { Bulkrax.default_work_type }.to('StillImage')
  end

  it 'reseeds valid_child_concerns from the final registration list' do
    expect(StillImage.valid_child_concerns).to eq Hyrax.config.curation_concerns
  end
end
