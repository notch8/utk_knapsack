# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::CsvFileSetEntryDecorator do
  let(:importer) do
    Bulkrax::Importer.create!(name: 'probe', admin_set_id: 'admin-set', parser_klass: 'Bulkrax::CsvParser',
                              user: ::User.system_user)
  end
  let(:entry) do
    Bulkrax::CsvFileSetEntry.create!(identifier: 'probe:fs', importerexporter: importer,
                                     parsed_metadata: { 'parents' => parents })
  end
  let(:parents) { ['probe:work'] }

  before { Bulkrax::ImporterRun.create!(importer:) }

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
