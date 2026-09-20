# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::CreateRelationshipsJobDecorator do
  let(:job) { Bulkrax::CreateRelationshipsJob.new }

  let(:parent_id) { Valkyrie::ID.new('parent-1') }
  let(:fs1_id)    { Valkyrie::ID.new('fs-1') }
  let(:fs2_id)    { Valkyrie::ID.new('fs-2') }
  let(:fs3_id)    { Valkyrie::ID.new('fs-3') }

  let(:fs1) { double('fs1', id: fs1_id) }
  let(:fs2) { double('fs2', id: fs2_id) }
  let(:fs3) { double('fs3', id: fs3_id) }

  let(:parent) do
    double('parent', id: parent_id, member_ids: [fs1_id, fs2_id, fs3_id],
                     representative_id: nil, thumbnail_id: nil)
  end

  let(:query_service) { double('query_service') }
  let(:persister)     { double('persister') }

  before do
    allow(fs1).to receive(:try).with(:sequence).and_return(['2'])
    allow(fs2).to receive(:try).with(:sequence).and_return(['1'])
    allow(fs3).to receive(:try).with(:sequence).and_return(['3'])

    allow(Hyrax).to receive(:query_service).and_return(query_service)
    allow(Hyrax).to receive(:persister).and_return(persister)
    allow(query_service).to receive(:find_by).with(id: parent_id).and_return(parent)
    allow(query_service).to receive(:find_members).with(resource: parent).and_return([fs1, fs2, fs3].lazy)
    allow(persister).to receive(:save).with(resource: parent).and_return(parent)
    allow(Bulkrax.object_factory).to receive(:update_index)

    allow(parent).to receive(:member_ids=)
    allow(parent).to receive(:representative_id=)
    allow(parent).to receive(:thumbnail_id=)
  end

  describe '#process_parent_as_work' do
    let(:parent_record) { double('parent_record', id: parent_id) }

    before do
      allow(job).to receive(:conditionally_acquire_lock_for).and_yield
      allow(Bulkrax::PendingRelationship).to receive(:where).and_return(Bulkrax::PendingRelationship.none)
    end

    context 'when members were added' do
      before do
        job.instance_variable_set(:@parent_record_members_added, true)
        allow(Bulkrax.object_factory).to receive(:save!).and_return(parent)
        allow(Bulkrax.object_factory).to receive(:find).and_return(parent)
        allow(Bulkrax.object_factory).to receive(:update_index)
        allow(Bulkrax.object_factory).to receive(:publish)
      end

      it 'calls sort_members_and_set_representative' do
        expect(job).to receive(:sort_members_and_set_representative).with(parent_id)

        job.send(:process_parent_as_work, parent_record:, parent_identifier: 'test')
      end
    end

    context 'when no members were added' do
      it 'skips sorting' do
        expect(job).not_to receive(:sort_members_and_set_representative)

        job.send(:process_parent_as_work, parent_record:, parent_identifier: 'test')
      end
    end
  end

  describe '#sort_members_and_set_representative' do
    it 'reorders member_ids by sequence' do
      job.send(:sort_members_and_set_representative, parent_id)

      expect(parent).to have_received(:member_ids=).with([fs2_id, fs1_id, fs3_id])
    end

    it 'sets representative_id to the first member in sequence order' do
      job.send(:sort_members_and_set_representative, parent_id)

      expect(parent).to have_received(:representative_id=).with(fs2_id)
    end

    it 'sets thumbnail_id to the first member in sequence order' do
      job.send(:sort_members_and_set_representative, parent_id)

      expect(parent).to have_received(:thumbnail_id=).with(fs2_id)
    end

    it 'persists and reindexes' do
      job.send(:sort_members_and_set_representative, parent_id)

      expect(persister).to have_received(:save).with(resource: parent)
      expect(Bulkrax.object_factory).to have_received(:update_index)
    end

    context 'when already sorted with correct representative' do
      let(:parent) do
        double('parent', id: parent_id, member_ids: [fs2_id, fs1_id, fs3_id],
                         representative_id: fs2_id, thumbnail_id: fs2_id)
      end

      it 'skips the save' do
        job.send(:sort_members_and_set_representative, parent_id)

        expect(persister).not_to have_received(:save)
      end
    end

    context 'when sorted but representative_id is wrong' do
      let(:parent) do
        double('parent', id: parent_id, member_ids: [fs2_id, fs1_id, fs3_id],
                         representative_id: fs3_id, thumbnail_id: fs2_id)
      end

      it 'corrects representative_id' do
        job.send(:sort_members_and_set_representative, parent_id)

        expect(parent).to have_received(:representative_id=).with(fs2_id)
        expect(persister).to have_received(:save)
      end
    end

    context 'when sorted but thumbnail_id is wrong' do
      let(:parent) do
        double('parent', id: parent_id, member_ids: [fs2_id, fs1_id, fs3_id],
                         representative_id: fs2_id, thumbnail_id: fs3_id)
      end

      it 'corrects thumbnail_id' do
        job.send(:sort_members_and_set_representative, parent_id)

        expect(parent).to have_received(:thumbnail_id=).with(fs2_id)
        expect(persister).to have_received(:save)
      end
    end

    context 'when a member has no usable sequence' do
      before { allow(fs3).to receive(:try).with(:sequence).and_return(nil) }

      it 'leaves member_ids untouched' do
        job.send(:sort_members_and_set_representative, parent_id)

        expect(parent).not_to have_received(:member_ids=)
        expect(persister).not_to have_received(:save)
      end
    end

    context 'when members are empty' do
      before { allow(query_service).to receive(:find_members).with(resource: parent).and_return([].lazy) }

      it 'does nothing' do
        job.send(:sort_members_and_set_representative, parent_id)

        expect(persister).not_to have_received(:save)
      end
    end
  end
end
