# frozen_string_literal: true

module HykuKnapsack
  module CustomQueries
    class FindFileSetsWithoutThumbnail
      THUMBNAIL = [{ '@id' => Hyrax::FileMetadata::Use::THUMBNAIL_IMAGE.to_s }].to_json.freeze
      WITHOUT_THUMBNAIL = <<~SQL.squish
        NOT EXISTS (
          SELECT 1 FROM orm_resources file_metadata
          WHERE file_metadata.internal_resource = 'Hyrax::FileMetadata'
            AND file_metadata.metadata @> jsonb_build_object(
              'pcdm_use', ?::jsonb,
              'file_set_id', jsonb_build_array(jsonb_build_object('id', orm_resources.id::text))
            )
            AND (
              orm_resources.metadata @> jsonb_build_object(
                'file_ids', jsonb_build_array(to_jsonb(file_metadata.id::text))
              )
              OR orm_resources.metadata @> jsonb_build_object(
                'file_ids', jsonb_build_array(jsonb_build_object('id', file_metadata.id::text))
              )
            )
        )
      SQL

      def self.queries
        [:find_file_sets_without_thumbnail]
      end

      def initialize(query_service:)
        @query_service = query_service
      end

      attr_reader :query_service

      delegate :resource_factory, to: :query_service
      delegate :orm_class, to: :resource_factory

      def find_file_sets_without_thumbnail(batch_size: 200)
        return to_enum(:find_file_sets_without_thumbnail, batch_size:) unless block_given?

        orm_class.where(internal_resource: 'Hyrax::FileSet')
                 .where(WITHOUT_THUMBNAIL, THUMBNAIL)
                 .find_each(batch_size:) { |row| yield resource_factory.to_resource(object: row) }
      end
    end
  end
end
