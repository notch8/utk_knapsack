# frozen_string_literal: true

require 'rails_helper'
require 'hyrax/specs/shared_specs/hydra_works'

RSpec.describe DigitalCollection do
  subject(:collection) { described_class.new }

  it_behaves_like 'a Hyrax::PcdmCollection'

  it 'is the configured collection model' do
    expect(Hyrax.config.collection_class).to eq described_class
  end

  it 'is flexible' do
    expect(described_class).to be_flexible
  end

  describe 'creator ordering' do
    it 'does not prepend OrderAlready, which a flexible model cannot support' do
      expect(described_class.ancestors.first).to eq described_class
    end

    it 'round trips values in the order they were assigned' do
      collection.creator = ['Zeta, Z', 'Alpha, A']

      expect(collection.creator).to eq ['Zeta, Z', 'Alpha, A']
    end

    it 'serializes through OrderAlready on write' do
      expect(OrderAlready::InputOrderSerializer).to receive(:serialize).with(['Zeta, Z']).and_call_original

      collection.creator = ['Zeta, Z']
    end
  end

  describe '#members_of' do
    it 'is empty before the collection is persisted' do
      expect(collection.members_of).to eq []
    end
  end

  describe '#member_collection_ids' do
    it 'is empty before the collection is persisted' do
      expect(collection.member_collection_ids).to eq []
    end
  end
end
