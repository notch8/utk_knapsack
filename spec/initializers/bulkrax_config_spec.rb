# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'config/initializers/bulkrax_config.rb' do
  describe 'fill_in_blank_source_identifiers' do
    let(:callback) { Bulkrax.fill_in_blank_source_identifiers }
    let(:account) { instance_double(Account, name: 'utk') }
    let(:site) { instance_double(Site, account: account) }
    let(:importer) { instance_double(Bulkrax::Importer, id: 42) }
    let(:entry) { instance_double(Bulkrax::Entry, importerexporter: importer) }

    before { allow(Site).to receive(:instance).and_return(site) }

    it 'builds a tenant/importer/index source identifier' do
      expect(callback.call(entry, 7)).to eq 'utk-42-7'
    end
  end

  describe 'qa_controlled_properties' do
    it 'includes resource_types' do
      expect(Bulkrax.qa_controlled_properties).to include('resource_types')
    end

    it 'is idempotent across reloads' do
      path = HykuKnapsack::Engine.root.join('config', 'initializers', 'bulkrax_config.rb').to_s
      block = Rails.application.config.to_prepare_blocks.find { |b| b.source_location.first == path }
      count_before = Bulkrax.qa_controlled_properties.count('resource_types')

      block.call

      expect(Bulkrax.qa_controlled_properties.count('resource_types')).to eq count_before
    end
  end
end
