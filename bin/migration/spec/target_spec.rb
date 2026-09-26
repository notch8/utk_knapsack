# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe Migration::Target do
  around do |example|
    saved = %w[DST_BUCKET DERIVATIVES_BUCKET DST_POD DEST_CONTEXT].to_h { |key| [key, ENV.delete(key)] }
    example.run
    ENV.update(saved.compact)
  end

  it 'defaults to the local stack' do
    expect(described_class.for(nil)).to have_attributes(bucket: 'utk-poc', derivatives_bucket: 'utk-poc', pod: nil)
  end

  it 'points prod at the production cluster' do
    expect(described_class.for('production')).to have_attributes(
      bucket: 'utk-production-repository-production-559021623471',
      pod: 'utk-production/utk-knapsack-production/deploy/utk-knapsack-production-hyrax'
    )
  end

  it 'lets an explicit bucket win over the preset' do
    ENV['DST_BUCKET'] = 'somewhere'
    expect(described_class.for('dev')).to have_attributes(bucket: 'somewhere', derivatives_bucket: 'somewhere')
  end
end
