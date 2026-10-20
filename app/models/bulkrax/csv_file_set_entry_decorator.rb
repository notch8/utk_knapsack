# frozen_string_literal: true

# OVERRIDE Bulkrax 10.0.0 Bulkrax::CsvFileSetEntry#parent_jobs (from
# FileSetEntryBehavior) to record a pending relationship to each parent work
# instead of skipping relationships. The knapsack's factories create file sets
# without attaching them, so CreateRelationshipsJob attaches them.
module Bulkrax
  module CsvFileSetEntryDecorator
    def parent_jobs
      # OVERRIDE: upstream returns false for file sets
      Array(parsed_metadata[related_parents_parsed_mapping]).each do |parent_identifier|
        next if parent_identifier.blank?

        PendingRelationship.create!(child_id: identifier,
                                    parent_id: parent_identifier,
                                    importer_run_id: importerexporter.last_run.id,
                                    order: id)
      end
    end
  end
end

Bulkrax::CsvFileSetEntry.prepend(Bulkrax::CsvFileSetEntryDecorator)
