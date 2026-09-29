# frozen_string_literal: true

# OVERRIDE Bulkrax 9.5.1: count an entry whose latest status is Pending as
# still pending. Bulkrax gives every entry that status at creation, so the
# stock IS NULL test sees nothing pending five minutes in and schedules the
# relationship pass before the file set entries have created their
# PendingRelationship rows. Remove once samvera/bulkrax#1223 ships.
module Bulkrax
  module ScheduleRelationshipsJobDecorator
    STILL_PENDING = "bulkrax_statuses.status_message IS NULL OR bulkrax_statuses.status_message = 'Pending'"

    def perform(importer_id:)
      importer = Importer.find(importer_id)
      pending_num = importer.entries.left_outer_joins(:latest_status).where(STILL_PENDING).count
      return reschedule(importer_id) unless pending_num.zero?

      super
    end
  end
end

Bulkrax::ScheduleRelationshipsJob.prepend(Bulkrax::ScheduleRelationshipsJobDecorator)
