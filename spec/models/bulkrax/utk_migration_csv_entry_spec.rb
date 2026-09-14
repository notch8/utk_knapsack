# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::UtkMigrationCsvEntry do
  def importer_for(parser)
    Bulkrax::Importer.create!(name: 'probe', admin_set_id: 'admin-set', parser_klass: parser,
                              user: ::User.system_user)
                     .tap { |importer| Bulkrax::ImporterRun.create!(importer:) }
  end

  describe 'a work row in a migration sheet' do
    let(:importer) { importer_for(Bulkrax::UtkMigrationCsvParser.to_s) }
    let(:entry) { described_class.create!(identifier: 'probe:work', importerexporter: importer) }

    it 'builds the migration factory' do
      expect(entry.factory).to be_a Bulkrax::UtkMigrationObjectFactory
    end
  end

  # The migration factory expects a digest and a preserved id, so a curator's
  # ordinary CSV import must never reach it.
  describe 'a work row in an ordinary sheet' do
    let(:importer) { importer_for(Bulkrax::CsvParser.to_s) }
    let(:entry) { Bulkrax::CsvEntry.create!(identifier: 'probe:work', importerexporter: importer) }

    it 'builds the factory Bulkrax is configured with' do
      expect(entry.factory).to be_a Bulkrax::ValkyrieObjectFactory
    end

    it 'is not the migration factory' do
      expect(entry.factory).not_to be_a Bulkrax::UtkMigrationObjectFactory
    end
  end

  it 'leaves the globally configured factory alone' do
    expect(Bulkrax.object_factory).to eq Bulkrax::ValkyrieObjectFactory
  end
end
