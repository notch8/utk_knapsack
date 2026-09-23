# frozen_string_literal: true

module Bulkrax
  # Creates works and file sets that repoint at content the legacy Fedora
  # application already holds, rather than depositing new content.
  # rubocop:disable Metrics/ClassLength
  class UtkMigrationObjectFactory < ValkyrieObjectFactory
    class MissingParentError < StandardError; end
    class MissingDigestError < StandardError; end
    SHA1 = /\A[0-9a-f]{40}\z/
    FILE_POINTER_FIELDS = %w[sha1 mime_type original_filename].freeze

    private

    def create_work(attrs)
      resource = klass.new(**work_attributes(attrs))
      resource.id = ::Valkyrie::ID.new(attrs[:id]) if attrs[:id].present?
      resource.admin_set_id ||= self.class.find_or_create_default_admin_set.id

      saved = Hyrax.persister.save(resource:)
      apply_permissions(saved, attrs[:visibility])
      initialize_workflow(saved)
      Hyrax.index_adapter.save(resource: Hyrax.query_service.find_by(id: saved.id))
      saved
    end

    def create_collection(attrs)
      resource = klass.new(**work_attributes(attrs))
      resource.id = ::Valkyrie::ID.new(attrs[:id]) if attrs[:id].present?
      resource.collection_type_gid ||= Hyrax::CollectionType.find_or_create_default_collection_type.to_global_id.to_s

      saved = Hyrax.persister.save(resource:)
      apply_permissions(saved, attrs[:visibility])
      Hyrax.index_adapter.save(resource: Hyrax.query_service.find_by(id: saved.id))
      saved
    end

    def create_file_set(attrs)
      digest = digest_for(attrs)
      parent = parent_work(attrs)

      file_set = Hyrax::FileSet.new(**file_set_attributes(attrs))
      file_set.id = ::Valkyrie::ID.new(attrs[:id]) if attrs[:id].present?
      file_set = Hyrax.persister.save(resource: file_set)

      file_set = attach_files(file_set, attrs, digest)
      apply_permissions(file_set, attrs[:visibility], inherit_from: parent)
      Hyrax.index_adapter.save(resource: Hyrax.query_service.find_by(id: file_set.id))
      file_set
    end

    def attach_files(file_set, attrs, digest)
      file_metadata = Hyrax.persister.save(resource: file_metadata_for(file_set, attrs, digest))
      derivatives = derivative_metadata_for(file_set).map { |d| Hyrax.persister.save(resource: d) }
      file_set.file_ids = [file_metadata.id, *derivatives.map(&:id)]
      linked = Hyrax.persister.save(resource: file_set)
      UtkMigrationCharacterizationJob.perform_later(file_metadata.id.to_s)
      linked
    end

    def digest_for(attrs)
      digest = attrs[:sha1].presence or raise MissingDigestError, "#{attrs[:source_identifier]} has no sha1"
      return digest if digest.match?(SHA1)

      raise MissingDigestError, "#{attrs[:source_identifier]} has #{digest.inspect}, which is not a sha1"
    end

    def file_label(attrs)
      Array.wrap(attrs[:original_filename].presence || attrs[:title]).first
    end

    def file_metadata_for(file_set, attrs, digest)
      Hyrax::FileMetadata.new(
        file_identifier: ::Valkyrie::ID.new(file_identifier_for(digest)),
        file_set_id: file_set.id,
        original_filename: file_label(attrs),
        mime_type: attrs[:mime_type],
        recorded_size: Array(attrs[:file_size]).compact,
        checksum: [digest],
        pcdm_use: [Hyrax::FileMetadata::Use::ORIGINAL_FILE]
      )
    end

    DERIVATIVE_USE = {
      'thumbnail' => Hyrax::FileMetadata::Use::THUMBNAIL_IMAGE,
      'extracted_text' => Hyrax::FileMetadata::Use::EXTRACTED_TEXT,
      'txt' => Hyrax::FileMetadata::Use::EXTRACTED_TEXT, # from IIIF Print
      'xml' => Hyrax::FileMetadata::Use::EXTRACTED_TEXT, # from IIIF Print
      'json' => Hyrax::FileMetadata::Use::EXTRACTED_TEXT # from IIIF Print
    }.freeze

    def derivative_metadata_for(file_set)
      Hyrax::DerivativePath.derivatives_for_reference(file_set).filter_map do |path|
        next unless File.size?(path)

        kind = File.basename(path, '.*').split('-').last
        Hyrax::FileMetadata.new(
          file_identifier: ::Valkyrie::ID.new("disk://#{path}"),
          file_set_id: file_set.id,
          original_filename: File.basename(path),
          mime_type: Marcel::MimeType.for(extension: File.extname(path)),
          pcdm_use: [DERIVATIVE_USE.fetch(kind, Hyrax::FileMetadata::Use::SERVICE_FILE)]
        )
      end
    end

    def file_identifier_for(digest)
      adapter = Hyrax.storage_adapter
      if adapter.is_a?(::Valkyrie::Storage::Disk)
        "disk://#{adapter.base_path.join(digest)}"
      else
        "shrine://#{digest}"
      end
    end

    def find_by_id
      super
    rescue ObjectFactoryInterface::ObjectNotFoundError
      false
    end

    def parent_work(attrs)
      identifier = Array(attrs[related_parents_parsed_mapping.to_sym] || attrs[:parents]).first
      raise MissingParentError, "#{attrs[:source_identifier]} names no parent" if identifier.blank?

      found = find_parent_by_entry(identifier) || find_parent_by_identifier(identifier)
      raise MissingParentError, "#{attrs[:source_identifier]} names #{identifier}, which was not found" if found.nil?

      found
    end

    def find_parent_by_entry(identifier)
      return nil if importer_run_id.blank?

      find_record(identifier, importer_run_id)&.last
    end

    def find_parent_by_identifier(identifier)
      self.class.search_by_property(value: identifier,
                                    name_field: work_identifier,
                                    search_field: work_identifier_search_field)
    end

    def initialize_workflow(resource)
      Hyrax::Workflow::WorkflowFactory.create(resource, {}, @user)
    rescue Sipity::StateError, Sipity::ConversionError => e
      Hyrax.logger.error(e)
    end

    def apply_permissions(resource, visibility, inherit_from: nil)
      if inherit_from
        Hyrax::AccessControlList.copy_permissions(source: inherit_from, target: resource)
      else
        template = Hyrax::PermissionTemplate.find_by(source_id: resource.try(:admin_set_id)&.to_s)
        Hyrax::PermissionTemplateApplicator.apply(template).to(model: resource) if template
      end

      resource.visibility = visibility if visibility.present?
      resource.permission_manager.acl.save
    end

    NON_METADATA = %i[id sha1 mime_type file_size label original_filename visibility
                      model source_identifier parents].freeze

    def permitted_attributes
      super + NON_METADATA
    end

    def work_attributes(attrs)
      fold_nested_attributes(attrs.except(*NON_METADATA).symbolize_keys.merge(identifier_attribute(attrs)))
    end

    def fold_nested_attributes(attrs)
      attrs.each_with_object({}) do |(key, value), folded|
        bare = key.to_s.sub(/_attributes\z/, '')

        if bare == key.to_s
          folded[key] = value
        else
          entries = (value.is_a?(Hash) ? value.values : Array(value))
          folded[bare.to_sym] = entries.map { |e| e.symbolize_keys.except(:_destroy).compact_blank }.reject(&:blank?)
        end
      end
    end

    def file_set_attributes(attrs)
      fold_nested_attributes(
        attrs.except(*NON_METADATA)
             .symbolize_keys
             .merge(identifier_attribute(attrs))
             .merge(title: Array(attrs[:title]),
                    label: file_label(attrs),
                    file_size: Array(attrs[:file_size]).compact)
      )
    end

    def identifier_attribute(attrs)
      value = attrs[work_identifier.to_sym].presence || attrs[:source_identifier].presence
      return {} if value.blank?

      { work_identifier.to_sym => Array(value) }
    end
  end
  # rubocop:enable Metrics/ClassLength
end
