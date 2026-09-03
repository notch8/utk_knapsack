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
end
