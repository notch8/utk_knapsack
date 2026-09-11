# frozen_string_literal: true

module HykuKnapsack
  # Reduce a flexible `sequence` value to the integer the file manager sorts on.
  #
  # `sequence` is declared `data_type: array` in the M3 profile with no maximum
  # cardinality, so a member can carry several values; the lowest wins. Values
  # that are not integers yield nil, which the file manager reads as unsorted.
  # The literal string "[]" is one of those: it appears in the legacy index in
  # place of an absent value and must never be read as data.
  class SequenceSortKey
    INTEGER = /\A[+-]?\d+\z/
    EMPTY_ARRAY_LITERAL = '[]'

    # @param value [Array, String, Integer, nil] a flexible `sequence` value
    # @return [Integer, nil] the lowest integer present, or nil when there is none
    def self.call(value)
      new(value).call
    end

    def initialize(value)
      @value = value
    end

    # @return [Integer, nil]
    def call
      integers.min
    end

    private

    attr_reader :value

    def integers
      Array.wrap(value).filter_map { |candidate| integer_for(candidate) }
    end

    def integer_for(candidate)
      return candidate if candidate.is_a?(Integer)

      string = candidate.to_s.strip
      return if string == EMPTY_ARRAY_LITERAL
      return unless string.match?(INTEGER)

      string.to_i
    end
  end
end
