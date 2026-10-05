# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0: generate derivatives only for intermediate files and PDFs, and point a
# parent that has no thumbnail yet at the file set once its thumbnail exists
module HykuKnapsack
  module ValkyrieCreateDerivativesJobDecorator
    include Hyrax::Lockable

    def perform(file_set_id, file_id, *args)
      return unless generate_derivatives_for?(file_set_id, file_id)

      super
    end

    private

    def generate_derivatives_for?(file_set_id, file_id)
      HykuKnapsack::DerivativeCandidate.match?(Hyrax.query_service.find_by(id: file_set_id),
                                                Hyrax.custom_queries.find_file_metadata_by(id: file_id))
    end

    def reindex_parent(file_set_id)
      adopt_as_thumbnail(Hyrax.query_service.find_by(id: file_set_id))
      super
    end

    def adopt_as_thumbnail(file_set)
      return unless file_set.thumbnail

      parent_id = Hyrax.custom_queries.find_parent_work(resource: file_set)&.id
      return unless parent_id

      acquire_lock_for(parent_id.to_s) do
        parent = Hyrax.query_service.find_by(id: parent_id)
        next if parent.thumbnail_id.present?

        parent.thumbnail_id = file_set.id
        parent.representative_id = file_set.id if parent.representative_id.blank?
        Hyrax.persister.save(resource: parent)
      end
    end
  end
end

ValkyrieCreateDerivativesJob.prepend(HykuKnapsack::ValkyrieCreateDerivativesJobDecorator)
