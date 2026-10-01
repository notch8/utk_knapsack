# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::FlexibleSchemaDecorator do
  it 'drops the schema memo when a profile is saved' do
    schema = Hyrax::FlexibleSchema.current_record

    schema.update!(updated_at: Time.current)

    expect(Hyrax::Current.flexible_schema).to be_nil
  end
end
