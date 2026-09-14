# frozen_string_literal: true

module Bulkrax
  module UtkMigrationFactory
    extend ActiveSupport::Concern

    def field_supported?(field)
      name = field.to_s.gsub('_attributes', '')
      return false if excluded?(name)

      UtkMigrationObjectFactory::FILE_POINTER_FIELDS.include?(name) || super
    end

    def factory
      @factory ||= UtkMigrationObjectFactory.new(attributes: parsed_metadata,
                                                 source_identifier_value: identifier,
                                                 work_identifier: parser.work_identifier,
                                                 work_identifier_search_field: parser.work_identifier_search_field,
                                                 related_parents_parsed_mapping: parser.related_parents_parsed_mapping,
                                                 replace_files:,
                                                 user:,
                                                 klass: factory_class,
                                                 importer_run_id: importerexporter.last_run.id,
                                                 update_files:)
    end
  end
end
