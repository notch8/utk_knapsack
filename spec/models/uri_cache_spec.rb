# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UriCache, type: :model do
  let(:uri) { 'http://example.com/resource' }

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

  it 'requires a value for a resolved uri' do
    expect(build(:uri_cache, value: nil)).not_to be_valid
    expect(build(:uri_cache, value: '')).not_to be_valid
  end

  it 'allows a failed uri without a value' do
    expect(build(:uri_cache, status: 'failed', value: nil, reason: 'Not Found(404)')).to be_valid
  end

  describe '.record_failure' do
    include ActiveSupport::Testing::TimeHelpers

    around { |example| freeze_time { example.run } }

    it 'retries a temporary failure after an hour' do
      cache = described_class.record_failure(uri, reason: 'timeout', permanent: false)

      expect(cache).to have_attributes(status: 'failed', value: nil, reason: 'timeout',
                                       permanent: false, attempts: 1, retry_after: 1.hour.from_now)
    end

    it 'doubles the wait on each repeated temporary failure' do
      3.times { described_class.record_failure(uri, reason: 'timeout', permanent: false) }

      expect(described_class.find_by(uri:)).to have_attributes(attempts: 3, retry_after: 4.hours.from_now)
    end

    it 'waits no more than a week between temporary retries' do
      create(:uri_cache, uri:, status: 'failed', value: nil, attempts: 20)

      expect(described_class.record_failure(uri, reason: 'timeout', permanent: false).retry_after)
        .to eq 7.days.from_now
    end

    it 'keeps a label that another lookup stored first' do
      create(:uri_cache, uri:, value: 'A label')

      expect(described_class.record_failure(uri, reason: 'timeout', permanent: false))
        .to have_attributes(status: 'resolved', value: 'A label', attempts: 0)
    end

    it 'retries a permanent failure after thirty days' do
      cache = described_class.record_failure(uri, reason: 'Not Found(404)', permanent: true)

      expect(cache).to have_attributes(permanent: true, retry_after: 30.days.from_now)
    end
  end

  describe '.record_success' do
    it 'clears an earlier failure' do
      create(:uri_cache, uri:, status: 'failed', value: nil, reason: 'timeout', attempts: 2,
                         retry_after: 1.hour.from_now)

      expect(described_class.record_success(uri, 'A label'))
        .to have_attributes(status: 'resolved', value: 'A label', reason: nil, attempts: 0, retry_after: nil)
    end
  end

  describe '#due?' do
    it 'is true for a failure whose wait has passed' do
      expect(build(:uri_cache, status: 'failed', value: nil, retry_after: 1.minute.ago)).to be_due
    end

    it 'is false for a failure still waiting' do
      expect(build(:uri_cache, status: 'failed', value: nil, retry_after: 1.minute.from_now)).not_to be_due
    end

    it 'is false for a resolved uri' do
      expect(build(:uri_cache)).not_to be_due
    end
  end

  describe '.reclassify_legacy_failures!' do
    it 'turns a cached deletion note into a permanent failure' do
      note = 'This authority record has been deleted because it is not a valid heading.'
      create(:uri_cache, uri:, value: "#{uri} (Failed to load URI) - #{note}")

      described_class.reclassify_legacy_failures!

      expect(described_class.find_by(uri:))
        .to have_attributes(status: 'failed', value: nil, reason: note, permanent: true, retry_after: nil)
    end

    it 'turns other cached failure text into a temporary failure due now' do
      create(:uri_cache, uri:, value: "#{uri} (No label found)")

      described_class.reclassify_legacy_failures!

      expect(described_class.find_by(uri:))
        .to have_attributes(status: 'failed', reason: 'No label found', permanent: false)
      expect(described_class.find_by(uri:)).to be_due
    end

    it 'leaves a real label alone' do
      create(:uri_cache, uri:, value: 'A label')

      expect { described_class.reclassify_legacy_failures! }.not_to(change { described_class.find_by(uri:).attributes })
    end
  end

  describe '#update_cache' do
    let(:cache) { create(:uri_cache, uri:) }

    it 'replaces the value with a fresh remote label' do
      allow(UriLabelResolver).to receive(:resolve_remote).with(uri)
                                                         .and_return(UriLabelResolver::Outcome.new(label: 'updated value'))

      expect { cache.update_cache }.to change { cache.reload.value }.to('updated value')
    end

    it 'keeps a resolved label when the refresh fails' do
      allow(UriLabelResolver).to receive(:resolve_remote).with(uri)
                                                         .and_return(UriLabelResolver::Outcome.new(reason: 'timeout', permanent: false))

      expect { cache.update_cache }.not_to(change { cache.reload.attributes })
    end

    it 'records another attempt for a failed uri' do
      failed = create(:uri_cache, uri:, status: 'failed', value: nil, attempts: 1)
      allow(UriLabelResolver).to receive(:resolve_remote).with(uri)
                                                         .and_return(UriLabelResolver::Outcome.new(reason: 'timeout', permanent: false))

      expect { failed.update_cache }.to change { failed.reload.attempts }.from(1).to(2)
    end
  end

  describe '.update_all_caches!' do
    it 'updates all caches' do
      allow(UriLabelResolver).to receive(:resolve_remote).and_return(UriLabelResolver::Outcome.new(label: 'updated value'))
      cache1 = create(:uri_cache, uri: 'http://example.com/1', value: 'old value 1')
      cache2 = create(:uri_cache, uri: 'http://example.com/2', value: 'old value 2')

      expect { described_class.update_all_caches! }
        .to change { cache1.reload.value }.to('updated value')
        .and change { cache2.reload.value }.to('updated value')
    end
  end
end
