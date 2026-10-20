# frozen_string_literal: true

# OVERRIDE Bulkrax 10.0.0 Bulkrax::ValkyrieObjectFactory#create_file_set
#   - create a file set without saving its parent work. Bulkrax appends each
#     file set to a copy of the work read before any lock, so two file sets
#     imported at once for one work each save a copy without the other, and one
#     drops out of member_ids. The file set entry records a pending relationship
#     instead, and CreateRelationshipsJob attaches every file set for the work
#     in one pass.
#   - fail a row that lists more than one file. Each file becomes a file set,
#     but the row's one identifier can relate only one of them to the work.
module Bulkrax
  module ValkyrieObjectFactoryFileSetDecorator
    private

    def create_file_set(attrs)
      attrs = HashWithIndifferentAccess.new(attrs)
      parent = find_record(attributes[related_parents_parsed_mapping].first, importer_run_id).last
      uploaded_files, = prep_fileset_content(attrs)
      # OVERRIDE: one file per file set row
      raise StandardError, "#{source_identifier_value} lists #{uploaded_files.size} files; a file set row takes one" if uploaded_files.size > 1

      payload = attach_unrelated(parent, uploaded_files, attrs.merge(attributes).symbolize_keys)
      payload[:job].enqueue
      payload[:file_set]
    end

    # OVERRIDE: create the file set outside update_work
    def attach_unrelated(parent, uploaded_files, params)
      HykuKnapsack::UnattachedUploadsHandler.new(work: parent)
                                            .add(files: uploaded_files, file_set_params: [params])
                                            .attach
                                            .first || raise(StandardError, "#{source_identifier_value} has no file to attach")
    end
  end
end

Bulkrax::ValkyrieObjectFactory.prepend(Bulkrax::ValkyrieObjectFactoryFileSetDecorator)
