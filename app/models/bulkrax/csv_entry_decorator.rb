# frozen_string_literal: true

# OVERRIDE Bulkrax 9.5.1: a row that resolves to an existing record changes
# only the columns it gives. Skip the create-time checks (title, file, parent)
# and the importer defaults (visibility, admin set, rights statement,
# collection type) that would otherwise overwrite what the record already has.
# A row matched by id also keeps the record's source identifier, which Bulkrax
# would replace with one generated for the blank column.
module Bulkrax
  module CsvEntryDecorator
    def validate_record
      super unless record.present? && updating_existing_record?
    end

    def add_ingested_metadata
      super
      parsed_metadata.delete(work_identifier) if record['id'].present? && updating_existing_record?
    end

    def add_visibility
      super unless updating_existing_record?
    end

    def add_rights_statement
      super if override_rights_statement || !updating_existing_record?
    end

    def add_metadata_for_model
      return super unless updating_existing_record?

      if factory_class == Bulkrax.file_model_class
        add_path_to_file
      elsif factory_class != Bulkrax.collection_model_class
        add_file unless importerexporter.metadata_only?
      end
    end

    private

    def updating_existing_record?
      return @updating_existing_record if defined?(@updating_existing_record)

      @updating_existing_record = existing_record.present?
    end

    def existing_record
      return Bulkrax.object_factory.find_or_nil(record['id']) if record['id'].present?

      Bulkrax.object_factory.search_by_property(klass: factory_class,
                                                value: record[source_identifier],
                                                search_field: parser.work_identifier_search_field,
                                                name_field: parser.work_identifier)
    end
  end
end

Bulkrax::CsvEntry.prepend(Bulkrax::CsvEntryDecorator)
