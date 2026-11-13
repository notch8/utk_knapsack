# frozen_string_literal: true

module HykuKnapsack
  class LocalSeed
    class Records
      ORM = Valkyrie::Persistence::Postgres::ORM::Resource
      INDEX_ORDER = %w[DigitalCollection Hyrax::FileSet].freeze
      UNINDEXED = %w[Hyrax::FileMetadata Hyrax::AccessControl].freeze

      class << self
        def call(**options)
          new(**options).call
        end
      end

      def initialize(dir:, io: $stdout)
        @dir = Pathname(dir)
        @io = io
      end

      def call
        rows = JSON.parse(dir.join('records.json').read)
        fresh = rows.reject { |row| ORM.exists?(id: row['id']) }
        localized = fresh.map { |row| localize(row) }
        ORM.transaction do
          ORM.insert_all(localized) if localized.any? # rubocop:disable Rails/SkipsModelValidations
          enqueue_derivatives(fresh)
        end
        permit_collections(rows)
        deposit_works(rows)
        index(rows)
        io.puts("Seeded #{fresh.size} new of #{rows.size} records")
      end

      private

      attr_reader :dir, :io

      def localize(row)
        metadata = row['metadata']
        metadata['schema_version'] = [schema_version] if metadata.key?('schema_version')
        metadata['admin_set_id'] = [{ 'id' => admin_set_id }] if metadata.key?('admin_set_id')
        metadata['collection_type_gid'] = [collection_type_gid] if metadata.key?('collection_type_gid')
        metadata['file_identifier'] = [{ 'id' => store(row) }] if row['internal_resource'] == 'Hyrax::FileMetadata'
        row.slice('id', 'internal_resource', 'lock_version', 'created_at', 'updated_at').merge('metadata' => metadata)
      end

      def schema_version
        @schema_version ||= Hyrax::FlexibleSchema.order(:id).last.id
      end

      def admin_set_id
        @admin_set_id ||= Hyrax::AdminSetCreateService.find_or_create_default_admin_set.id.to_s
      end

      def collection_type_gid
        @collection_type_gid ||= Hyrax::CollectionType.find_or_create_default_collection_type.to_global_id.to_s
      end

      def store(row)
        metadata = row['metadata']
        file_set = Hyrax::FileSet.new(id: metadata['file_set_id'].first['id'])
        Tempfile.create(binmode: true) do |copy|
          IO.copy_stream(dir.join('files', row['id']).to_s, copy)
          copy.rewind
          Hyrax.storage_adapter.upload(resource: file_set, file: copy, original_filename: metadata['original_filename'].first).id.to_s
        end
      end

      def permit_collections(rows)
        of_type(rows, 'DigitalCollection').each do |row|
          next if Hyrax::PermissionTemplate.exists?(source_id: row['id'])

          Hyrax::Collections::PermissionsCreateService.create_default(collection: Hyrax.query_service.find_by(id: row['id']),
                                                                      creating_user: User.find_by(email: LocalSeed::ADMIN_EMAIL))
        end
      end

      def deposit_works(rows)
        rows.select { |row| Hyrax.config.registered_curation_concern_types.include?(row['internal_resource']) }.each do |row|
          work = Hyrax.query_service.find_by(id: row['id'])
          workflow = Hyrax::PermissionTemplate.find_by!(source_id: work.admin_set_id.to_s).active_workflow
          Sipity::Entity.find_or_create_by!(proxy_for_global_id: Hyrax::GlobalID(work).to_s) do |entity|
            entity.workflow = workflow
            entity.workflow_state = workflow.workflow_states.find_by!(name: 'deposited')
          end
        end
      end

      def index(rows)
        rows.reject { |row| UNINDEXED.include?(row['internal_resource']) }
            .sort_by { |row| INDEX_ORDER.index(row['internal_resource']) || INDEX_ORDER.size }
            .each { |row| Hyrax.index_adapter.save(resource: Hyrax.query_service.find_by(id: row['id'])) }
      end

      def enqueue_derivatives(rows)
        of_type(rows, 'Hyrax::FileMetadata').each do |row|
          ValkyrieCreateDerivativesJob.perform_later(row['metadata']['file_set_id'].first['id'], row['id'])
        end
      end

      def of_type(rows, internal_resource)
        rows.select { |row| row['internal_resource'] == internal_resource }
      end
    end
  end
end
