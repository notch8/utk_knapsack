# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::FlexibleSchemaDecorator do
  it 'drops the schema memos when a profile is saved' do
    schema = Hyrax::FlexibleSchema.current_record
    Hyrax::Schema.m3_schema_loader.attributes_for(schema: 'Pdf', version: schema.id)

    schema.update!(updated_at: Time.current)

    expect([Hyrax::Current.flexible_schema, Hyrax::Current.flexible_schemas_by_version]).to eq([nil, nil])
  end
end
