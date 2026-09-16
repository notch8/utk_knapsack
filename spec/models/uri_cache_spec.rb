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
