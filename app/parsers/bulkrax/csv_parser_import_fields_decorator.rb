# frozen_string_literal: true

# OVERRIDE Bulkrax 9.5.1: read the column names from the first row instead of
# parsing and merging every row. Importer#mapping asks for them in every
# ImportWorkJob, so the whole sheet was read once per record.
module Bulkrax
  module CsvParserImportFieldsDecorator
    def import_fields
      @import_fields ||= first_record_keys || super
    end

    private

    def first_record_keys
      return if @records.present?

      path = only_updates ? parser_fields['partial_import_file_path'] : import_file_path
      options = { headers: true, encoding: 'utf-8',
                  header_converters: ->(h) { h.to_s.gsub(/[^\w\d\. -]+/, '').strip.to_sym } }
      row = CSV.foreach(path, **options.merge(entry_class.csv_read_data_options)).first
      entry_class.data_for_entry(row, nil, self).keys.compact.uniq if row
    end
  end
end

Bulkrax::CsvParser.prepend(Bulkrax::CsvParserImportFieldsDecorator)
