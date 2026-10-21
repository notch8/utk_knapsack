# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0 Hyrax::WorkUploadsHandler#attach and #append_to_work to
# create file sets without adding them to the work, leaving the work unsaved and
# the ingest unqueued; Bulkrax's relationship pass attaches each file set and then
# queues its ingest
module HykuKnapsack
  class UnattachedUploadsHandler < Hyrax::WorkUploadsHandler
    # @return [Array<Hash>] a { file_set:, user:, job: } payload per file set created
    def attach
      # OVERRIDE: no lock, no work save, no file.set.attached, and the ingest job left unqueued
      Array.wrap(files).each_with_index.map do |file, index|
        make_file_set_and_ingest(file, file_set_params[index] || {})
      end
    end

    private

    # OVERRIDE: leave the work's members, representative and thumbnail alone
    def append_to_work(_file_set); end
  end
end
