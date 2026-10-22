# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'config/initializers/4browse_everything.rb' do
  let(:initializer) { HykuKnapsack::Engine.root.join('config', 'initializers', '4browse_everything.rb') }

  around do |example|
    original = BrowseEverything.config.to_h
    example.run
  ensure
    BrowseEverything.configure(original)
  end

  def load_with(env)
    stub_const('ENV', ENV.to_h.except(*env.keys).merge(env.compact))
    load initializer
    BrowseEverything.config
  end

  it 'configures only the S3 provider from the environment' do
    config = load_with('BROWSE_EVERYTHING_S3_BUCKET' => 'utk-ingest',
                       'BROWSE_EVERYTHING_S3_REGION' => 'us-east-2',
                       'BROWSE_EVERYTHING_S3_ACCESS_KEY_ID' => 'key',
                       'BROWSE_EVERYTHING_S3_SECRET_ACCESS_KEY' => 'secret')

    expect(config.keys).to eq ['s3']
    expect(config[:s3]).to include(bucket: 'utk-ingest', region: 'us-east-2', app_key: 'key', app_secret: 'secret')
  end

  it 'falls back to the default AWS credentials without keys' do
    config = load_with('BROWSE_EVERYTHING_S3_BUCKET' => 'utk-ingest', 'BROWSE_EVERYTHING_S3_REGION' => 'us-east-2',
                       'BROWSE_EVERYTHING_S3_ACCESS_KEY_ID' => nil, 'BROWSE_EVERYTHING_S3_SECRET_ACCESS_KEY' => nil)

    expect(config[:s3].keys).to contain_exactly('bucket', 'region')
  end

  it 'uses the default AWS credentials when only one key is set' do
    config = load_with('BROWSE_EVERYTHING_S3_BUCKET' => 'utk-ingest', 'BROWSE_EVERYTHING_S3_REGION' => 'us-east-2',
                       'BROWSE_EVERYTHING_S3_ACCESS_KEY_ID' => 'key', 'BROWSE_EVERYTHING_S3_SECRET_ACCESS_KEY' => nil)

    expect(config[:s3].keys).to contain_exactly('bucket', 'region')
  end

  it 'configures no provider, not even the file system, without a bucket' do
    config = load_with('BROWSE_EVERYTHING_S3_BUCKET' => nil, 'BROWSE_EVERYTHING_S3_REGION' => 'us-east-2')

    expect(config).to be_empty
  end

  it 'configures no provider without a region' do
    config = load_with('BROWSE_EVERYTHING_S3_BUCKET' => 'utk-ingest', 'BROWSE_EVERYTHING_S3_REGION' => nil)

    expect(config).to be_empty
  end
end
