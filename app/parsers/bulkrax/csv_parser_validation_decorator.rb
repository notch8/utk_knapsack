# frozen_string_literal: true

# OVERRIDE Bulkrax (acc18e4): guided import's missing required columns check
# reads headers only, so a sheet that only updates existing works is told to
# add columns those works already fill. Drop a model's missing field when
# every row of that model is an existing record with a value for it.
module Bulkrax
  module CsvParserValidationDecorator
    private

    def run_validations(csv_data, all_ids, headers, source_id_key, mappings, field_metadata, missing_required, zip_file, mapping_manager: nil, csv_in_zip: false) # rubocop:disable Metrics/ParameterLists
      results = super
      records = {}
      missing_required.reject! do |entry|
        rows = csv_data.select { |row| (row[:model].presence || Bulkrax.default_work_type).to_s == entry[:model].to_s }
        rows.all? do |row|
          key = [row[:raw_row]['id'], row[:source_identifier]]
          record = records.fetch(key) { records[key] = existing_record(row) }
          Array(record.try(entry[:field])).any?(&:present?)
        end
      end
      results
    end

    def existing_record(row)
      id = row[:raw_row]['id']
      return Bulkrax.object_factory.find_or_nil(id) if id.present?

      record_by_source_identifier(row[:source_identifier])
    end

    def record_by_source_identifier(value)
      return if value.blank?

      name_field, mapping = Bulkrax.field_mappings['Bulkrax::CsvParser'].find { |_key, field| field['source_identifier'] }
      Bulkrax.object_factory.search_by_property(value:, name_field:, search_field: mapping['search_field'])
    rescue StandardError
      nil
    end
  end
end

Bulkrax::CsvParser.singleton_class.prepend(Bulkrax::CsvParserValidationDecorator)
