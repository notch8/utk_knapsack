# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UriCache, type: :model do
  it 'validates presence of uri' do
    expect(build(:uri_cache, uri: nil)).not_to be_valid
    expect(build(:uri_cache, uri: '')).not_to be_valid
  end

  it 'validates uniqueness of uri' do
    create(:uri_cache)
    new_cache = build(:uri_cache)

    expect(new_cache).not_to be_valid
    expect(new_cache.errors[:uri]).to include('has already been taken')
  end

  it 'validates presence of value' do
    expect(build(:uri_cache, value: nil)).not_to be_valid
    expect(build(:uri_cache, value: '')).not_to be_valid
  end

  describe '#update_cache' do
    let(:uri) { 'http://example.com/resource' }
    let(:cache) { create(:uri_cache, uri: uri) }

    before do
      allow(UriLabelResolver).to receive(:resolve_remote).with(uri).and_return('updated value')
    end

    it 'updates the value by re-resolving remotely, bypassing cache' do
      expect { cache.update_cache }.to change { cache.reload.value }.to('updated value')
    end

    context 'when resolve_remote returns an error annotation' do
      before do
        allow(UriLabelResolver).to receive(:resolve_remote).with(uri)
          .and_return("#{uri} (Failed to load URI)")
      end

      it 'does not overwrite the cached value' do
        expect { cache.update_cache }.not_to(change { cache.reload.value })
      end
    end
  end

  describe '.update_all_caches!' do
    before do
      allow(UriLabelResolver).to receive(:resolve_remote).and_return('updated value')
    end

    it 'updates all caches' do
      cache1 = create(:uri_cache, uri: 'http://example.com/1', value: 'old value 1')
      cache2 = create(:uri_cache, uri: 'http://example.com/2', value: 'old value 2')

      expect do
        described_class.update_all_caches!
      end.to change { cache1.reload.value }.to('updated value')
        .and change { cache2.reload.value }.to('updated value')
    end
  end

  describe '.create' do
    it 'creates a new cache entry with uri and value' do
      cache = described_class.create(uri: 'http://example.com/resource', value: 'some value')

      expect(cache).to be_persisted
      expect(cache.uri).to eq('http://example.com/resource')
      expect(cache.value).to eq('some value')
    end

    it 'rejects a record without a value' do
      cache = described_class.create(uri: 'http://example.com/resource')

      expect(cache).not_to be_persisted
      expect(cache.errors[:value]).to include("can't be blank")
    end
  end
end
