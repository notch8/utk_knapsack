# frozen_string_literal: true

module HykuKnapsack
  class ReindexWorkJob < Hyrax::ApplicationJob
    include GoodJob::ActiveJobExtensions::Concurrency

    DELAY = 5.minutes

    queue_as Hyrax.config.ingest_queue_name
    good_job_control_concurrency_with(enqueue_limit: 1, key: -> { "#{self.class.name}-#{Apartment::Tenant.current}-#{arguments.first}" })
    discard_on Valkyrie::Persistence::ObjectNotFoundError

    def perform(work_id)
      Hyrax.index_adapter.save(resource: Hyrax.query_service.find_by(id: work_id))
    end
  end
end
