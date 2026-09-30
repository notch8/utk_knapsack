# frozen_string_literal: true

class UriCache < ApplicationRecord
  RESOLVED = 'resolved'
  FAILED = 'failed'
  PERMANENT_FAILURE_WAIT = 30.days
  FIRST_RETRY_WAIT = 1.hour
  LONGEST_RETRY_WAIT = 7.days
  LEGACY_DELETION_NOTE = /\A \(Failed to load URI\) - (.+)\z/m

  validates :uri, presence: true, uniqueness: true
  validates :value, presence: true, if: :resolved?
  validates :status, inclusion: { in: [RESOLVED, FAILED] }

  def self.record_success(uri, label)
    find_or_initialize_by(uri:).tap { |cache| cache.record_success!(label) }
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    find_by(uri:)
  end

  def self.record_failure(uri, reason:, permanent:)
    find_or_initialize_by(uri:).tap { |cache| cache.record_failure!(reason:, permanent:) unless cache.resolved? && cache.persisted? }
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    find_by(uri:)
  end

  def self.update_all_caches!
    find_each(&:update_cache)
  end

  def self.reclassify_legacy_failures!
    where('LEFT(value, LENGTH(uri)) = uri').find_each do |cache|
      text = cache.value.delete_prefix(cache.uri)
      note = text[LEGACY_DELETION_NOTE, 1]
      cache.update!(status: FAILED, value: nil, permanent: note.present?, retry_after: nil,
                    reason: note || text.strip.delete_prefix('(').delete_suffix(')'))
    end
  end

  def resolved?
    status == RESOLVED
  end

  def failed?
    status == FAILED
  end

  def due?
    failed? && (retry_after.nil? || retry_after <= Time.current)
  end

  def record_success!(label)
    update!(status: RESOLVED, value: label, reason: nil, permanent: false, attempts: 0, retry_after: nil)
  end

  def record_failure!(reason:, permanent:)
    self.attempts += 1
    update!(status: FAILED, value: nil, reason:, permanent:, retry_after: Time.current + retry_wait(permanent))
  end

  def update_cache
    outcome = UriLabelResolver.resolve_remote(uri)
    if outcome.label
      record_success!(outcome.label)
    elsif failed?
      record_failure!(reason: outcome.reason, permanent: outcome.permanent)
    end
  end

  private

  def retry_wait(permanent)
    return PERMANENT_FAILURE_WAIT if permanent

    [FIRST_RETRY_WAIT * (2**(attempts - 1)), LONGEST_RETRY_WAIT].min
  end
end
