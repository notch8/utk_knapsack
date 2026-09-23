# frozen_string_literal: true

Rails.application.config.to_prepare do
  next unless Hyku.bulkrax_enabled?

  Bulkrax.default_work_type = 'StillImage'

  unless Bulkrax.parsers.any? { |p| p[:class_name] == Bulkrax::UtkMigrationCsvParser.to_s }
    Bulkrax.parsers += [{ name: 'UTK Migration - CSV',
                          class_name: Bulkrax::UtkMigrationCsvParser.to_s,
                          partial: 'csv_fields' }]
  end
end
