# frozen_string_literal: true

module HykuKnapsack
  class IntermediateFile
    FRAGMENT = Hyrax::FileMetadata::Use::INTERMEDIATE_FILE.fragment

    def self.match?(types)
      Array(types).any? { |type| type.to_s.split(%r{[#/:]}).last.to_s.casecmp?(FRAGMENT) }
    end
  end
end
