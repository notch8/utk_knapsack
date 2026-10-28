# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::BrowseEverythingS3DriverDecorator do
  subject(:driver) do
    BrowseEverything::Driver::S3.new(bucket: 'utk-ingest', region: 'us-east-2', app_key: 'key', app_secret: 'secret')
  end

  let(:extras) { driver.link_for('burial_001.tif').last }

  around do |example|
    Aws.config[:s3] = { stub_responses: { head_object: { content_length: 10 } } }
    example.run
  ensure
    Aws.config.delete(:s3)
  end

  it 'sends a signed link expiry as a time in the future' do
    expect(Time.zone.parse(extras[:expires])).to be_within(1.minute).of(Time.current + 14_400)
  end

  it 'sends the file size Bulkrax waits for before an import runs' do
    expect(extras[:file_size]).to eq 10
  end

  it 'gives the retriever an expiry it can check' do
    spec = { 'url' => 'https://utk-ingest.s3.amazonaws.com/burial_001.tif', 'expires' => extras[:expires], 'file_size' => extras[:file_size].to_s }
    stub_request(:any, spec['url']).to_return(body: 'tif')

    expect { BrowseEverything::Retriever.new.retrieve(spec) {} }.not_to raise_error
  end
end
