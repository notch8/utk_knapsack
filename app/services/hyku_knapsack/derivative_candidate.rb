# frozen_string_literal: true

module HykuKnapsack
  class DerivativeCandidate
    def self.match?(file_set, original)
      types = file_set.try(:rdf_type)
      pdf?(original) || PcdmUse.intermediate_file?(types) || PcdmUse.thumbnail_image?(types)
    end

    def self.pdf?(original)
      original.pdf? || File.extname(original.original_filename.to_s).casecmp?('.pdf')
    end
  end
end
