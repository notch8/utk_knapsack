# frozen_string_literal: true

# OVERRIDE Bulkrax 10.0.0 Bulkrax::ValkyrieObjectFactory#create_file_set
#   - create a file set without saving its parent work. Bulkrax appends each
#     file set to a copy of the work read before any lock, so two file sets
#     imported at once for one work each save a copy without the other, and one
#     drops out of member_ids. The file set entry records a pending relationship
#     instead, and CreateRelationshipsJob attaches every file set for the work
#     in one pass.
#   - give the file set the row's visibility, which Bulkrax drops because it
#     passes file set params without the uploaded file id the handler matches
#     on. A row without one inherits the work's visibility, embargo and lease,
#     before the ingest job is queued, since that job saves the copy of the
#     file set it loaded.
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

    # OVERRIDE: create the file set outside update_work, keyed by uploaded file id so the row's visibility applies
    def attach_unrelated(parent, uploaded_files, params)
      payload = HykuKnapsack::UnattachedUploadsHandler.new(work: parent)
                                                      .add(files: uploaded_files,
                                                           file_set_params: uploaded_files.map { |file| params.merge(uploaded_file_id: file.id.to_s) })
                                                      .attach
                                                      .first || raise(StandardError, "#{source_identifier_value} has no file to attach")
      # OVERRIDE: a row without a visibility inherits the work's embargo and lease
      payload[:file_set] = inherit_embargo_and_lease(from: parent, to: payload[:file_set]) if params[:visibility].blank?
      payload
    end

    def inherit_embargo_and_lease(from:, to:)
      embargoed = Hyrax::EmbargoManager.new(resource: from).copy_embargo_to(target: to)
      leased = Hyrax::LeaseManager.new(resource: from).copy_lease_to(target: to)
      return to unless embargoed || leased

      to.permission_manager.acl.save
      Hyrax.persister.save(resource: to)
    end
  end
end

Bulkrax::ValkyrieObjectFactory.prepend(Bulkrax::ValkyrieObjectFactoryFileSetDecorator)
