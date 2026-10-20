# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::ReindexWorkJob do
  let(:work) { Pdf.new(id: 'work-1', title: ['work']) }
  let(:index_adapter) { instance_double(Valkyrie::Indexing::Solr::IndexingAdapter, save: nil) }

  before { allow(Hyrax).to receive(:index_adapter).and_return(index_adapter) }

  it 'reindexes the work' do
    allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-1').and_return(work)

    described_class.perform_now('work-1')

    expect(index_adapter).to have_received(:save).with(resource: work)
  end

  it 'gives up on a work that no longer exists' do
    allow(Hyrax.query_service).to receive(:find_by).and_raise(Valkyrie::Persistence::ObjectNotFoundError)

    expect { described_class.perform_now('gone') }.not_to raise_error
    expect(index_adapter).not_to have_received(:save)
  end

  context 'when queued through GoodJob' do
    around do |example|
      test_adapter = described_class.queue_adapter
      described_class.disable_test_adapter
      default_adapter = described_class.queue_adapter
      described_class.queue_adapter = GoodJob::Adapter.new(execution_mode: :external)
      example.run
    ensure
      described_class.queue_adapter = default_adapter
      described_class.enable_test_adapter(test_adapter)
    end

    def waiting_reindexes
      GoodJob::Job.where(job_class: described_class.name).unfinished.group(:concurrency_key).count
    end

    def queue_in(tenant, work_id)
      allow(Apartment::Tenant).to receive(:current).and_return(tenant)
      described_class.set(wait: described_class::DELAY).perform_later(work_id)
    end

    it 'keeps one waiting reindex per work, however many pages finish' do
      3.times { queue_in('tenant-a', 'work-1') }
      queue_in('tenant-a', 'work-2')

      expect(waiting_reindexes).to eq("#{described_class.name}-tenant-a-work-1" => 1,
                                      "#{described_class.name}-tenant-a-work-2" => 1)
    end

    it 'keeps tenants apart when they share a work id, as migrated works can' do
      queue_in('tenant-a', 'work-1')
      queue_in('tenant-b', 'work-1')

      expect(waiting_reindexes.values).to eq [1, 1]
    end
  end
end
