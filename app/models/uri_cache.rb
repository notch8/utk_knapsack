# frozen_string_literal: true

class UriCache < ApplicationRecord
  validates :uri, presence: true, uniqueness: true
  validates :value, presence: true
end
