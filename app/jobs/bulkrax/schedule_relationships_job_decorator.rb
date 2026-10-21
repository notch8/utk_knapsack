# frozen_string_literal: true

# OVERRIDE Bulkrax 10.0.0 Bulkrax::ScheduleRelationshipsJob#perform to wait while
# any entry is still Pending. Upstream counts entries joined to a status with no
# message, but the parser gives every entry a Pending status when it creates it
# and the join is not limited to the latest status, so the check never waits.
# The relationships pass then runs five minutes in and misses every entry that
# finishes later, such as a file set waiting on its parent work.
#
# Bug reported upstream as samvera/bulkrax#1258; this mirrors the fix made there.
# Remove this decorator once the knapsack runs a Bulkrax release with that fix.
module Bulkrax
  module ScheduleRelationshipsJobDecorator
    # Relationships wait until no entry is Pending. If no entry has finished for
    # STALL_LIMIT, a stuck entry or a backed-up queue is holding them, so relate
    # the parents that are ready and check again every STALLED_CHECK_WAIT for
    # entries that finish later, until GIVE_UP_LIMIT. CreateRelationshipsJob
    # deletes each pending relationship it links, so every pass handles only
    # what is left. Re-running an entry schedules this job again.
    STALL_LIMIT = 24.hours
    STALLED_CHECK_WAIT = 1.hour
    GIVE_UP_LIMIT = 7.days
    # Statuses that mean an entry finished; a relationship error is also
    # written as a status and must not count as progress.
    FINISHED_STATUSES = %w[Complete Failed Skipped Deleted].freeze

    # OVERRIDE: wait on the entries' denormalized latest status, relating what is ready once stalled (samvera/bulkrax#1258)
    def perform(importer_id:)
      importer = Importer.find(importer_id)
      pending = importer.entries.pending
      return create_relationships(importer, importer.last_run.parents) unless pending.exists?

      last_progress = last_progress_at(importer)
      return reschedule(importer_id) if last_progress > STALL_LIMIT.ago

      giving_up = last_progress < GIVE_UP_LIMIT.ago
      log_stall(importer_id, pending, giving_up:)
      ScheduleRelationshipsJob.set(wait: STALLED_CHECK_WAIT).perform_later(importer_id:) unless giving_up
      create_relationships(importer, ready_parents(importer, pending))
    end

    private

    def log_stall(importer_id, pending, giving_up:)
      still_pending = "#{pending.count} #{'entry'.pluralize(pending.count)} still Pending"
      if giving_up
        Rails.logger.error("Bulkrax: no entry of importer #{importer_id} has finished in #{GIVE_UP_LIMIT.inspect}; " \
                           "creating the relationships that are ready and no longer checking, with #{still_pending}")
      else
        Rails.logger.warn("Bulkrax: no entry of importer #{importer_id} has finished in #{STALL_LIMIT.inspect}; " \
                          "creating the relationships that are ready with #{still_pending}")
      end
    end

    def create_relationships(importer, parent_ids)
      parent_ids.each do |parent_id|
        Bulkrax.relationship_job_class.constantize.perform_later(parent_identifier: parent_id,
                                                                 importer_run_id: importer.last_run.id)
      end
    end

    def last_progress_at(importer)
      [Status.where(statusable: importer.entries, status_message: FINISHED_STATUSES).maximum(:created_at),
       importer.last_run.created_at].compact.max
    end

    # Relating a parent fails, and marks it with the error, while the parent or
    # any child it still has to link is Pending. An identifier with no entry in
    # this import is an existing record, so it counts as ready. Known limit: a
    # cell that names a Pending row's record id rather than its source
    # identifier is not recognized as Pending.
    def ready_parents(importer, pending)
      pending_identifiers = pending.select(:identifier)
      relationships = importer.last_run.pending_relationships
      blocked = relationships.where(parent_id: pending_identifiers).or(relationships.where(child_id: pending_identifiers))
      relationships.where.not(parent_id: blocked.select(:parent_id)).distinct.pluck(:parent_id)
    end
  end
end

Bulkrax::ScheduleRelationshipsJob.prepend(Bulkrax::ScheduleRelationshipsJobDecorator)
