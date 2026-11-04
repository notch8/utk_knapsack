# frozen_string_literal: true

Rails.application.config.to_prepare do
  next unless Hyku.bulkrax_enabled?

  Bulkrax.default_work_type = 'StillImage'
  Bulkrax::Entry.default_work_type = Bulkrax.default_work_type
end
