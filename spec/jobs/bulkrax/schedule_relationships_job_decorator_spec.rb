# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::ScheduleRelationshipsJobDecorator do
  let(:job) { Bulkrax::ScheduleRelationshipsJob.new }
  let(:importer) { Bulkrax::Importer.create!(name: 'probe', admin_set_id: 'x', user: User.system_user, parser_klass: 'Bulkrax::CsvParser', parser_fields: {}) }
  let(:run) { Bulkrax::ImporterRun.create!(importer:) }

  def entry_with_status(message)
    entry = Bulkrax::CsvEntry.create!(importerexporter: importer, identifier: SecureRandom.uuid)
    entry.statuses.create!(status_message: message, runnable: run) if message
    entry
  end

  before { Bulkrax::PendingRelationship.create!(importer_run: run, parent_id: 'parent-1', child_id: 'child-1', order: 1) }

  it 'schedules the relationship pass once every entry has finished' do
    entry_with_status('Complete')

    expect { job.perform(importer_id: importer.id) }
      .to have_enqueued_job(Bulkrax::CreateRelationshipsJob).with(parent_identifier: 'parent-1', importer_run_id: run.id)
  end

  it 'waits while an entry is still Pending, the status Bulkrax gives every entry at creation' do
    entry_with_status('Complete')
    entry_with_status('Pending')

    expect { job.perform(importer_id: importer.id) }.to have_enqueued_job(Bulkrax::ScheduleRelationshipsJob).with(importer_id: importer.id)
    expect(Bulkrax::CreateRelationshipsJob).not_to have_been_enqueued
  end

  it 'still waits for an entry with no status at all' do
    entry_with_status(nil)

    expect { job.perform(importer_id: importer.id) }.to have_enqueued_job(Bulkrax::ScheduleRelationshipsJob)
    expect(Bulkrax::CreateRelationshipsJob).not_to have_been_enqueued
  end
end
