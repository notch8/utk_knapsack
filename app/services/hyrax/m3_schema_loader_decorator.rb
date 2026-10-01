# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0: resolve each schema version once per request, as FlexibleSchema.current_record does
module Hyrax
  module M3SchemaLoaderDecorator
    private

    def resolve_schema(version)
      schemas = Hyrax::Current.flexible_schemas_by_version ||= {}
      return schemas[version] if schemas.key?(version)

      schemas[version] = super
    end
  end
end

Hyrax::Current.attribute :flexible_schemas_by_version
Hyrax::M3SchemaLoader.prepend(Hyrax::M3SchemaLoaderDecorator)
