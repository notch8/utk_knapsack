# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SiteDecorator do
  it 'drops the schema memos when the tenant caches are reset' do
    Hyrax::FlexibleSchema.current_record
    Hyrax::Schema.m3_schema_loader.attributes_for(schema: 'Pdf', version: Hyrax::FlexibleSchema.current_schema_id)

    Site.reset!

    expect([Hyrax::Current.flexible_schema, Hyrax::Current.flexible_schemas_by_version]).to eq([nil, nil])
  end

  it 'starts a new site on the Digital Collection home and show themes' do
    expect(Site.new.attributes.slice('home_theme', 'show_theme'))
      .to eq('home_theme' => 'digital_collection', 'show_theme' => 'digital_collection_show')
  end

  it 'keeps the themes an admin saved' do
    site = Site.create!(home_theme: 'reference', show_theme: 'reference_show')

    expect(Site.find(site.id).attributes.slice('home_theme', 'show_theme'))
      .to eq('home_theme' => 'reference', 'show_theme' => 'reference_show')
  end
end
