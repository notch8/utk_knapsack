# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'config/initializers/2flexible_knapsack.rb' do
  let(:initializer) { HykuKnapsack::Engine.root.join('config', 'initializers', '2flexible_knapsack.rb') }
  let(:utk_types) { %w[StillImage Audio Book CompoundObject Newspaper Pdf Video] }

  around do |example|
    keys = %w[HYRAX_FLEXIBLE HYRAX_FLEXIBLE_CLASSES HYRAX_DISABLE_INCLUDE_METADATA]
    preserved = keys.index_with { |key| ENV.fetch(key, nil) }
    begin
      example.run
    ensure
      preserved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    end
  end

  it 'defaults HYRAX_FLEXIBLE before anything reads it lazily' do
    ENV['HYRAX_FLEXIBLE'] = nil
    load initializer

    expect(ENV.fetch('HYRAX_FLEXIBLE')).to eq 'true'
  end

  context 'when flexible metadata is on' do
    before { ENV['HYRAX_FLEXIBLE'] = 'true' }

    it "overwrites the host app's flexible classes with UTK's" do
      ENV['HYRAX_FLEXIBLE_CLASSES'] = 'GenericWorkResource,ImageResource,EtdResource,OerResource'
      load initializer

      expect(ENV.fetch('HYRAX_FLEXIBLE_CLASSES').split(','))
        .to eq %w[AdminSetResource CollectionResource Hyrax::FileSet] + utk_types
    end
  end

  context 'when flexible metadata is off' do
    before { ENV['HYRAX_FLEXIBLE'] = 'false' }

    it 'leaves the environment alone' do
      ENV['HYRAX_FLEXIBLE_CLASSES'] = 'AdminSetResource,CollectionResource'

      expect { load initializer }.not_to(change { ENV.fetch('HYRAX_FLEXIBLE_CLASSES', nil) })
    end
  end
end
# rubocop:enable RSpec/DescribeClass
