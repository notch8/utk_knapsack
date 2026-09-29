# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0: generate derivatives only for intermediate files and PDFs
module HykuKnapsack
  module ValkyrieCreateDerivativesJobDecorator
    def perform(file_set_id, file_id, *args)
      return unless generate_derivatives_for?(file_set_id, file_id)

      super
    end

    private

    def generate_derivatives_for?(file_set_id, file_id)
      HykuKnapsack::DerivativeCandidate.match?(Hyrax.query_service.find_by(id: file_set_id),
                                                Hyrax.custom_queries.find_file_metadata_by(id: file_id))
    end
  end
end

ValkyrieCreateDerivativesJob.prepend(HykuKnapsack::ValkyrieCreateDerivativesJobDecorator)
