# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteDecorator do
  it 'drops the schema memo when the tenant caches are reset' do
    Hyrax::FlexibleSchema.current_record

    Site.reset!

    expect(Hyrax::Current.flexible_schema).to be_nil
  end
end
