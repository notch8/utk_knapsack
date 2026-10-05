# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteDecorator do
  it 'drops the schema memos when the tenant caches are reset' do
    Hyrax::FlexibleSchema.current_record
    Hyrax::Schema.m3_schema_loader.attributes_for(schema: 'Pdf', version: Hyrax::FlexibleSchema.current_schema_id)

    Site.reset!

    expect([Hyrax::Current.flexible_schema, Hyrax::Current.flexible_schemas_by_version]).to eq([nil, nil])
  end
end
