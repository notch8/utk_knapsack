# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0: a flexible form declares its profile's fields when it is built, so ask a
# built form, not its class, which fields are required
module Hyrax
  module Forms
    module BatchUploadFormDecorator
      def required_fields
        return super unless Hyrax.config.use_valkyrie?

        payload = payload_class.new
        return super unless payload.try(:flexible?)

        Hyrax::Forms::ResourceForm.for(resource: payload, admin_set_id: model.try(:admin_set_id)).singleton_class.required_fields
      end
    end
  end
end

Hyrax::Forms::BatchUploadForm.prepend(Hyrax::Forms::BatchUploadFormDecorator)
