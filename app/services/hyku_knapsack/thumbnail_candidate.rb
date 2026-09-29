# frozen_string_literal: true

module HykuKnapsack
  class ThumbnailCandidate
    def self.match?(file_set, original)
      !original.audio? && DerivativeCandidate.match?(file_set, original)
    end
  end
end
