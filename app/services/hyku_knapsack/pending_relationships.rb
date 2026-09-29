# frozen_string_literal: true

module HykuKnapsack
  class PendingRelationships
    def self.call(**options)
      new(**options).call
    end

    def initialize(dry_run: false, io: $stdout)
      @dry_run = dry_run
      @io = io
    end

    def call
      enqueued = 0
      parents.each do |run_id, parent_id|
        reason = skip_reason(run_id, parent_id)
        if reason
          io.puts("#{run_id} #{parent_id} skipped, #{reason}")
          next
        end

        io.puts("#{run_id} #{parent_id}")
        Bulkrax::CreateRelationshipsJob.perform_later(parent_identifier: parent_id, importer_run_id: run_id) unless dry_run
        enqueued += 1
      end
      io.puts("#{enqueued} relationship jobs #{dry_run ? 'would be enqueued' : 'enqueued'}")
      enqueued
    end

    private

    attr_reader :dry_run, :io

    def parents
      Bulkrax::PendingRelationship.distinct.order(:importer_run_id, :parent_id).pluck(:importer_run_id, :parent_id)
    end

    def skip_reason(run_id, parent_id)
      return 'no such work or collection in this tenant' unless present?(parent_id)
      return 'a relationship job is already queued' if queued?(run_id, parent_id)

      nil
    end

    def queued?(run_id, parent_id)
      GoodJob::Job.where(job_class: 'Bulkrax::CreateRelationshipsJob', finished_at: nil)
                  .where("serialized_params->>'tenant' = :tenant", tenant: Apartment::Tenant.current)
                  .where("serialized_params->'arguments'->0->>'parent_identifier' = :parent", parent: parent_id)
                  .where("serialized_params->'arguments'->0->>'importer_run_id' = :run", run: run_id.to_s)
                  .exists?
    end

    def present?(identifier)
      quoted = %("#{RSolr.solr_escape(identifier)}")
      Hyrax::SolrService.count("id:#{quoted} OR bulkrax_identifier_tesim:#{quoted}").positive?
    end
  end
end
