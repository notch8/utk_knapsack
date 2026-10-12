# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::ImportFileSetJobDecorator do
  let(:importer) do
    Bulkrax::Importer.create!(name: 'probe', admin_set_id: 'admin-set', parser_klass: 'Bulkrax::UtkMigrationCsvParser',
                              user: ::User.system_user,
                              field_mapping: Bulkrax.field_mappings['Bulkrax::UtkMigrationCsvParser'],
                              parser_fields: { 'import_file_path' => 'unused.csv' })
  end
  let(:run) { importer.importer_runs.create! }
  let!(:parent) { Bulkrax::UtkMigrationCsvEntry.create!(importerexporter: importer, identifier: 'w:1', raw_metadata: {}) }
  let(:file_set) do
    Bulkrax::UtkMigrationCsvFileSetEntry.create!(importerexporter: importer, identifier: 'w:1_OBJ_fileset',
                                                 raw_metadata: { 'parents' => 'w:1' }, import_attempts: 4)
  end
  let(:job) { Bulkrax::ImportFileSetJob.new }

  before { allow(job).to receive(:find_record).and_return([nil, nil]) }

  it 'keeps waiting while the parent entry is pending' do
    expect { job.perform(file_set.id, run.id) }.to have_enqueued_job(Bulkrax::ImportFileSetJob).with(file_set.id, run.id)
    expect(file_set.reload.status).to eq 'Pending'
  end

  it 'stops waiting a day into the run' do
    run.update!(created_at: 2.days.ago)

    expect { job.perform(file_set.id, run.id) }.not_to have_enqueued_job(Bulkrax::ImportFileSetJob)
    expect(file_set.reload.status).to eq 'Failed'
  end

  it 'fails as Bulkrax does once the parent entry is done' do
    parent.set_status_info(nil, run)

    expect { job.perform(file_set.id, run.id) }.not_to have_enqueued_job(Bulkrax::ImportFileSetJob)
    expect(file_set.reload.status).to eq 'Failed'
  end
end
