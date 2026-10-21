# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::CsvFileSetEntryDecorator do
  let(:importer) do
    Bulkrax::Importer.create!(name: 'probe', admin_set_id: 'admin-set', parser_klass: 'Bulkrax::CsvParser',
                              user: ::User.system_user)
  end
  let(:entry) do
    Bulkrax::CsvFileSetEntry.create!(identifier: 'probe:fs', importerexporter: importer,
                                     raw_metadata: { 'source_identifier' => 'probe:fs' },
                                     parsed_metadata: { 'parents' => parents })
  end
  let(:parents) { ['probe:work'] }

  before { Bulkrax::ImporterRun.create!(importer:) }

  describe '#add_visibility' do
    it "leaves a blank visibility blank instead of taking the importer's default" do
      entry.parsed_metadata['visibility'] = ''
      entry.add_visibility

      expect(entry.parsed_metadata).not_to have_key('visibility')
    end

    it "keeps the row's visibility" do
      entry.parsed_metadata['visibility'] = 'restricted'
      entry.add_visibility

      expect(entry.parsed_metadata['visibility']).to eq 'restricted'
    end
  end

  it 'records a pending relationship to the parent work' do
    entry.parent_jobs

    expect(Bulkrax::PendingRelationship.where(child_id: 'probe:fs').pluck(:parent_id, :importer_run_id))
      .to eq [['probe:work', importer.last_run.id]]
  end

  context 'with a blank parent among several' do
    let(:parents) { ['probe:work', '', 'probe:other'] }

    it 'records one pending relationship per named parent' do
      entry.parent_jobs

      expect(Bulkrax::PendingRelationship.where(child_id: 'probe:fs').pluck(:parent_id))
        .to contain_exactly('probe:work', 'probe:other')
    end
  end
end
