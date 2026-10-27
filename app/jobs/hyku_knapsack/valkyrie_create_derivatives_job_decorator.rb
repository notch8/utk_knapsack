# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0: generate derivatives only for intermediate files, supplied thumbnail images
# and PDFs, point a parent that has no thumbnail or representative yet at the file set once its
# thumbnail exists, and queue a reindex of the parent so its text includes every page, not only the
# thumbnail's
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
      file_set = Hyrax.query_service.find_by(id: file_set_id)
      parent_id = Hyrax.custom_queries.find_parent_work_id(resource: file_set)
      if parent_id
        adopt_as_thumbnail(file_set, parent_id)
        HykuKnapsack::ReindexWorkJob.set(wait: HykuKnapsack::ReindexWorkJob::DELAY).perform_later(parent_id.to_s)
      end
      super
    end

    def adopt_as_thumbnail(file_set, parent_id)
      return unless file_set.thumbnail

      roles = PcdmUse.thumbnail_image?(file_set.try(:rdf_type)) ? %i[thumbnail_id] : %i[thumbnail_id representative_id]
      acquire_lock_for(parent_id.to_s) do
        parent = Hyrax.query_service.find_by(id: parent_id)
        vacant = roles.select { |role| parent.public_send(role).blank? }
        next if vacant.empty?

        vacant.each { |role| parent.public_send("#{role}=", file_set.id) }
        Hyrax.persister.save(resource: parent)
      end
    end
  end
end

ValkyrieCreateDerivativesJob.prepend(HykuKnapsack::ValkyrieCreateDerivativesJobDecorator)
