# frozen_string_literal: true

module HykuKnapsack
  class DerivativeCandidate
    def self.match?(file_set, original)
      pdf?(original) || IntermediateFile.match?(file_set.try(:rdf_type))
    end

    def self.pdf?(original)
      original.pdf? || File.extname(original.original_filename.to_s).casecmp?('.pdf')
    end
  end
end
