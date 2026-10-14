# frozen_string_literal: true

module HykuKnapsack
  module PcdmUse
    class << self
      def intermediate_file?(types)
        match?(types, Hyrax::FileMetadata::Use::INTERMEDIATE_FILE)
      end

      def transcript?(types)
        match?(types, Hyrax::FileMetadata::Use::TRANSCRIPT)
      end

      private

      def match?(types, use)
        Array(types).any? { |type| type.to_s.split(%r{[#/:]}).last.to_s.casecmp?(use.fragment) }
      end
    end
  end
end
