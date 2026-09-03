# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'config/metadata_profiles/m3_profile.yaml' do
  let(:path) { HykuKnapsack::Engine.root.join('config', 'metadata_profiles', 'm3_profile.yaml') }
  let(:profile) { YAML.safe_load_file(path.to_s) }

  it 'is the profile Hyrax resolves first' do
    expect(Hyrax::Schema.m3_schema_loader.config_paths.first).to eq path.to_s
  end

  it 'loads the way Hyrax::FlexibleSchema.create_default_schema loads it, without permitted_classes' do
    expect { profile }.not_to raise_error
  end

  it 'passes Hyrax validation with no errors' do
    validator = Hyrax::FlexibleSchemaValidatorService.new(profile:)
    validator.validate!

    expect(validator.errors).to be_empty
  end

  it 'defines every registered curation concern' do
    expect(profile['classes'].keys)
      .to include(*Hyrax.config.registered_curation_concern_types)
  end

  it 'defines the classes Hyrax requires of every profile' do
    expect(profile['classes'].keys)
      .to include(*Hyrax::FlexibleSchemaValidatorService::REQUIRED_CLASSES)
  end
end
# rubocop:enable RSpec/DescribeClass
