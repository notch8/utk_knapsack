# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::PendingRelationships do
  let(:io) { StringIO.new }
  let(:importer) { Bulkrax::Importer.create!(name: 'probe', admin_set_id: 'x', user: User.system_user, parser_klass: 'Bulkrax::CsvParser', parser_fields: {}) }
  let(:run) { Bulkrax::ImporterRun.create!(importer:) }

  before do
    Bulkrax::PendingRelationship.create!(importer_run: run, parent_id: 'probe:work', child_id: 'probe:fs1', order: 1)
    Bulkrax::PendingRelationship.create!(importer_run: run, parent_id: 'probe:work', child_id: 'probe:fs2', order: 2)
    Bulkrax::PendingRelationship.create!(importer_run: run, parent_id: 'collections:gone', child_id: 'probe:work', order: 3)
    allow(Hyrax::SolrService).to receive(:count) { |query| query.include?('"probe\:work"') ? 1 : 0 }
  end

  it 'enqueues one relationship job per pending parent that exists' do
    expect(described_class.call(io:)).to eq(1)
    expect(Bulkrax::CreateRelationshipsJob).to have_been_enqueued.with(parent_identifier: 'probe:work', importer_run_id: run.id).once
  end

  it 'skips a parent this tenant does not have and says so' do
    described_class.call(io:)

    expect(Bulkrax::CreateRelationshipsJob).not_to have_been_enqueued.with(parent_identifier: 'collections:gone', importer_run_id: run.id)
    expect(io.string).to include('collections:gone skipped')
  end

  it 'asks Solr for the whole identifier, not its tokens' do
    described_class.call(io:, dry_run: true)

    expect(Hyrax::SolrService).to have_received(:count).with('id:"collections\\:gone" OR bulkrax_identifier_tesim:"collections\\:gone"')
  end

  def queue_relationship_job(tenant: Apartment::Tenant.current, finished_at: nil)
    GoodJob::Job.create!(active_job_id: SecureRandom.uuid, job_class: 'Bulkrax::CreateRelationshipsJob', queue_name: 'default',
                         finished_at:,
                         serialized_params: { 'job_class' => 'Bulkrax::CreateRelationshipsJob', 'tenant' => tenant,
                                              'arguments' => [{ 'parent_identifier' => 'probe:work', 'importer_run_id' => run.id }] })
  end

  it 'skips a pair whose relationship job is already queued and says so' do
    queue_relationship_job

    expect(described_class.call(io:)).to eq(0)
    expect(Bulkrax::CreateRelationshipsJob).not_to have_been_enqueued
    expect(io.string).to include('probe:work skipped, a relationship job is already queued')
  end

  it 'does not treat a finished job as queued' do
    queue_relationship_job(finished_at: Time.current)

    expect(described_class.call(io:)).to eq(1)
  end

  it 'ignores another tenant\'s job for the same run id and parent' do
    queue_relationship_job(tenant: 'another-tenant')

    expect(described_class.call(io:)).to eq(1)
  end

  it 'lists without enqueueing on a dry run' do
    expect(described_class.call(io:, dry_run: true)).to eq(1)
    expect(Bulkrax::CreateRelationshipsJob).not_to have_been_enqueued
    expect(io.string).to include('1 relationship jobs would be enqueued')
  end
end
