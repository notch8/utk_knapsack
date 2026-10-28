# frozen_string_literal: true

# OVERRIDE Bulkrax 10.0.0: an import whose cloud files are still downloading waits for them. Bulkrax
# read each file's size and raised on the first one not yet on disk, failing the import.
module Bulkrax
  module ImporterJobDecorator
    private

    def all_files_completed?(importer)
      originals = importer.parser_fields['original_file_paths']
      return false if originals.present? && !originals.all? { |path| File.exist?(path) }

      super
    end
  end
end

Bulkrax::ImporterJob.prepend(Bulkrax::ImporterJobDecorator)
