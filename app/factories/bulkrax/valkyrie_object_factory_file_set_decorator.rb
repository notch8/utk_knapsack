# frozen_string_literal: true

# OVERRIDE Bulkrax 10.0.0 Bulkrax::ValkyrieObjectFactory#create_file_set
#   - create a file set without saving its parent work. Bulkrax appends each
#     file set to a copy of the work read before any lock, so two file sets
#     imported at once for one work each save a copy without the other, and one
#     drops out of member_ids. The file set entry records a pending relationship
#     instead, and CreateRelationshipsJob attaches every file set for the work
#     in one pass, then queues its ingest, so characterization and derivatives
#     run once the file set has a parent.
#   - give the file set the row's visibility, which Bulkrax drops because it
#     passes file set params without the uploaded file id the handler matches
#     on. A row without one inherits the work's visibility, embargo and lease.
#   - fail a row that lists more than one file. Each file becomes a file set,
#     but the row's one identifier can relate only one of them to the work.
# OVERRIDE Bulkrax 10.0.0 Bulkrax::ValkyrieObjectFactory#update_file_set
#   - replace the file set's original file with the row's remote file when the
#     importer updates files, which Bulkrax downloads and discards. The old
#     original, its derivative records and its derivatives on disk go, so only
#     the new file's remain, and the parent work is reindexed for its members'
#     text.
# OVERRIDE Bulkrax 10.0.0 Bulkrax::ValkyrieObjectFactory::FileFactoryInnerWorkings#new_remote_files
#   - skip the import_url check for a file set, which Hyrax::FileSet does not
#     have; the checksum decides whether its file changed.
module Bulkrax
  module ValkyrieObjectFactoryFileSetDecorator
    private

    def create_file_set(attrs)
      attrs = HashWithIndifferentAccess.new(attrs)
      parent = find_record(attributes[related_parents_parsed_mapping].first, importer_run_id).last
      uploaded_files, = prep_fileset_content(attrs)
      # OVERRIDE: one file per file set row
      raise StandardError, "#{source_identifier_value} lists #{uploaded_files.size} files; a file set row takes one" if uploaded_files.size > 1

      attach_unrelated(parent, uploaded_files, attrs.merge(attributes).symbolize_keys)[:file_set]
    end

    def update_file_set(attrs)
      attrs = HashWithIndifferentAccess.new(attrs)
      remote_files = Array(attrs[:remote_files])
      raise StandardError, "#{source_identifier_value} lists #{remote_files.size} files; a file set row takes one" if remote_files.size > 1

      file_set = perform_transaction_for(object:, attrs: attrs.merge(attributes).symbolize_keys) do
        transactions['change_set.update_file_set']
      end
      remote_files.empty? ? file_set : replace_original_file(file_set, remote_files.first)
    end

    # OVERRIDE: drop the old original and everything derived from it, since storage without versions adds a second original
    def replace_original_file(file_set, remote_file)
      path = download_file(remote_file[:url])
      previous = file_set.original_file
      return file_set if previous && unchanged?(previous, path)

      stale = Hyrax.custom_queries.find_files(file_set:).to_a
      Hyrax::FileSetDerivativesService.new(file_set).cleanup_derivatives
      File.open(path) { |io| Hyrax::ValkyrieUpload.file(io:, filename: remote_file[:file_name], file_set:, user:) }
      file_set = Hyrax.query_service.find_by(id: file_set.id)
      stale.reject! { |file| file.id.to_s == previous.id.to_s } if previous && original_files(file_set).size == 1
      detach(file_set, stale).tap { |saved| reindex_parent_of(saved) }
    end

    def detach(file_set, files)
      return file_set if files.empty?

      ids = files.map { |file| file.id.to_s }
      file_set.file_ids = file_set.file_ids.reject { |id| ids.include?(id.to_s) }
      Hyrax.persister.save(resource: file_set).tap do |saved|
        Hyrax.index_adapter.save(resource: saved)
        files.each { |file| file.original_file? ? destroy_original(file) : delete_record(file) }
      end
    end

    def destroy_original(file)
      transactions['file_metadata.destroy'].call(file).value!
    end

    def delete_record(file)
      Hyrax.persister.delete(resource: file)
      Hyrax.publisher.publish('file.metadata.deleted', metadata: file)
    end

    def reindex_parent_of(file_set)
      parent_id = Hyrax.custom_queries.find_parent_work_id(resource: file_set)
      HykuKnapsack::ReindexWorkJob.set(wait: HykuKnapsack::ReindexWorkJob::DELAY).perform_later(parent_id.to_s) if parent_id
    end

    # OVERRIDE: a migrated original carries legacy's SHA1, an uploaded one the MD5 characterization records
    def unchanged?(file_metadata, path)
      Array(file_metadata.checksum).intersect?([Digest::MD5.file(path).hexdigest, Digest::SHA1.file(path).hexdigest])
    end

    def original_files(file_set)
      Hyrax.custom_queries.find_many_file_metadata_by_use(resource: file_set, use: Hyrax::FileMetadata::Use::ORIGINAL_FILE).to_a
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

  module ValkyrieFileFactoryInnerWorkingsDecorator
    def new_remote_files
      return super unless object.is_a?(Bulkrax.file_model_class)

      @new_remote_files ||= parsed_remote_files.select { |file| file[:url]&.match(URI::ABS_URI) }
    end
  end
end

Bulkrax::ValkyrieObjectFactory.prepend(Bulkrax::ValkyrieObjectFactoryFileSetDecorator)
Bulkrax::ValkyrieObjectFactory::FileFactoryInnerWorkings.prepend(Bulkrax::ValkyrieFileFactoryInnerWorkingsDecorator)
