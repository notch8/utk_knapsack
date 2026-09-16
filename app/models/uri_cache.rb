# frozen_string_literal: true

class UriCache < ApplicationRecord
  validates :uri, presence: true, uniqueness: true
  validates :value, presence: true

  def update_cache
    resolved = UriLabelResolver.resolve_remote(uri)
    update!(value: resolved) if resolved.present? && !resolved.start_with?(uri)
  end

  def self.update_all_caches!
    find_each(&:update_cache)
  end
end
