# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::UtkMigrationCsvFileSetEntry do
  let(:importer) do
    Bulkrax::Importer.create!(name: 'probe', admin_set_id: 'admin-set',
                              parser_klass: 'Bulkrax::UtkMigrationCsvParser',
                              user: ::User.system_user)
  end
  let(:entry) do
    described_class.create!(identifier: 'probe:fs', importerexporter: importer,
                            parsed_metadata:)
  end
  let(:parsed_metadata) { { 'parents' => ['probe:work'] } }

  # `excluded?` reads the importer's mapping, which would parse the CSV; these
  # examples are about the overrides, not about reading a file.
  before { allow(entry).to receive(:mapping).and_return({}) }

  describe 'factory selection' do
    it 'builds the migration factory rather than the global one' do
      Bulkrax::ImporterRun.create!(importer:)

      expect(entry.factory).to be_a Bulkrax::UtkMigrationObjectFactory
    end
  end

  describe 'the file pointer fields' do
    Bulkrax::UtkMigrationObjectFactory::FILE_POINTER_FIELDS.each do |field|
      it "keeps #{field}, which Hyrax::FileSet does not declare as a property" do
        expect(entry.field_supported?(field)).to be true
      end
    end
  end

  describe 'a column the tenant excludes' do
    it 'stays excluded even though the migration claims it' do
      allow(entry).to receive(:mapping).and_return('sha1' => { 'excluded' => true })

      expect(entry.field_supported?('sha1')).to be false
    end
  end

  describe 'the row checks' do
    # Bulkrax rejects a file set row with no filename. These rows carry a digest
    # instead, so that check has nothing to work with; the parent check still
    # applies, because a file set with no work is as broken here as anywhere.
    it 'accepts a row that names a parent but no file' do
      expect { entry.add_metadata_for_model }.not_to raise_error
    end

    it 'rejects a row with no parent' do
      entry.parsed_metadata = {}

      expect { entry.add_metadata_for_model }
        .to raise_error(Bulkrax::FileSetEntryBehavior::OrphanFileSetError)
    end
  end

  describe 'parent relationships' do
    # Upstream suppresses these for file sets because the stock factory attaches
    # them itself. This one does not, so without the pending relationship no file
    # set is ever attached to its work.
    it 'records a pending relationship per parent' do
      Bulkrax::ImporterRun.create!(importer:)

      expect { entry.parent_jobs }
        .to change { Bulkrax::PendingRelationship.where(child_id: 'probe:fs').count }.by(1)
    end
  end
end
