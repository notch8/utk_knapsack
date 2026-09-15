# frozen_string_literal: true

class UriCache < ApplicationRecord
  validates :uri, presence: true, uniqueness: true
  validates :value, presence: true

  before_validation :resolve_value, on: :create, if: -> { value.blank? }

  def update_cache
    resolved = UriLabelResolver.label_for(uri)
    update!(value: resolved) if resolved.present? && resolved != uri
  end

  def self.update_all_caches!
    find_each(&:update_cache)
  end

  private

  def resolve_value
    self.value = UriLabelResolver.label_for(uri)
    raise StandardError, uri if value == uri
  end
end
