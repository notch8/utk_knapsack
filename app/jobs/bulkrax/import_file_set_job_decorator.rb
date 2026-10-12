# frozen_string_literal: true

# OVERRIDE Bulkrax 9.5.1: keep waiting for a parent work whose entry is still
# Pending instead of failing the file set after five tries. A deep work queue
# can hold the parent back for hours; stop a day into the run.
module Bulkrax
  module ImportFileSetJobDecorator
    PARENT_WAIT = 1.day

    private

    def validate_parent!(parent_identifier)
      @parent_identifier = parent_identifier
      super
    end

    def handle_retry(entry, importer_run_id, error)
      return super unless ImporterRun.find(importer_run_id).created_at > PARENT_WAIT.ago && parent_pending?(entry)

      ImportFileSetJob.set(wait: 5.minutes).perform_later(entry.id, importer_run_id)
    end

    def parent_pending?(entry)
      entry.importerexporter.entries.find_by(identifier: @parent_identifier)&.status == 'Pending'
    end
  end
end

Bulkrax::ImportFileSetJob.prepend(Bulkrax::ImportFileSetJobDecorator)
