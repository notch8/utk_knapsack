# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::CreateRelationshipsJobDecorator do
  let(:job) { Bulkrax::CreateRelationshipsJob.new }

  let(:parent_id) { Valkyrie::ID.new('parent-1') }
  let(:fs1_id)    { Valkyrie::ID.new('fs-1') }
  let(:fs2_id)    { Valkyrie::ID.new('fs-2') }
  let(:fs3_id)    { Valkyrie::ID.new('fs-3') }

  let(:intermediate_file) { 'http://pcdm.org/use#IntermediateFile' }
  let(:preservation_file) { 'http://pcdm.org/use#PreservationFile' }
  let(:markup) { 'http://pcdm.org/file-format-types#Markup' }

  let(:fs1) { double('fs1', id: fs1_id) }
  let(:fs2) { double('fs2', id: fs2_id) }
  let(:fs3) { double('fs3', id: fs3_id) }

  let(:parent) do
    double('parent', id: parent_id, member_ids: [fs1_id, fs2_id, fs3_id],
                     representative_id: nil, thumbnail_id: nil)
  end

  let(:query_service) { double('query_service') }
  let(:persister)     { double('persister') }

  let(:file_metadata) { {} }

  def stub_member(member, sequence:, rdf_type: [intermediate_file], thumbnail: true)
    allow(member).to receive(:try).with(:sequence).and_return(sequence)
    allow(member).to receive(:try).with(:rdf_type).and_return(rdf_type)
    allow(member).to receive(:file_set?).and_return(true)
    original = Valkyrie::ID.new("#{member.id}-original")
    thumb = Valkyrie::ID.new("#{member.id}-thumbnail")
    file_metadata[original] = double('original', thumbnail_file?: false, file_set_id: member.id)
    file_metadata[thumb] = double('thumbnail', thumbnail_file?: true, file_set_id: member.id)
    allow(member).to receive(:file_ids).and_return(thumbnail ? [original, thumb] : [original])
  end

  before do
    stub_member(fs1, sequence: ['2'])
    stub_member(fs2, sequence: ['1'])
    stub_member(fs3, sequence: ['3'])

    allow(Hyrax).to receive(:query_service).and_return(query_service)
    allow(Hyrax).to receive(:persister).and_return(persister)
    allow(query_service).to receive(:find_by).with(id: parent_id).and_return(parent)
    allow(query_service).to receive(:find_members).with(resource: parent).and_return([fs1, fs2, fs3].lazy)
    allow(query_service).to receive(:find_many_by_ids) { |ids:| ids.map { |id| file_metadata.fetch(id) } }
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

    it 'sets representative_id to the first IntermediateFile in sequence order' do
      job.send(:sort_members_and_set_representative, parent_id)

      expect(parent).to have_received(:representative_id=).with(fs2_id)
    end

    it 'sets thumbnail_id to the first IntermediateFile in sequence order' do
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

    context 'when the first member in sequence order is not an IntermediateFile' do
      before do
        stub_member(fs1, sequence: ['2'], rdf_type: [preservation_file, intermediate_file])
        stub_member(fs2, sequence: ['1'], rdf_type: [markup])
      end

      it 'keeps the sequence order but picks the IntermediateFile as representative' do
        job.send(:sort_members_and_set_representative, parent_id)

        expect(parent).to have_received(:member_ids=).with([fs2_id, fs1_id, fs3_id])
        expect(parent).to have_received(:representative_id=).with(fs1_id)
        expect(parent).to have_received(:thumbnail_id=).with(fs1_id)
      end
    end

    context 'when rdf_type names IntermediateFile with another scheme or case' do
      before do
        stub_member(fs1, sequence: ['2'], rdf_type: [markup], thumbnail: false)
        stub_member(fs2, sequence: ['1'], rdf_type: [markup], thumbnail: false)
        stub_member(fs3, sequence: ['3'], rdf_type: ['https://pcdm.org/use#intermediatefile'], thumbnail: false)
      end

      it 'still recognizes it' do
        job.send(:sort_members_and_set_representative, parent_id)

        expect(parent).to have_received(:representative_id=).with(fs3_id)
      end
    end

    context 'when members share a sequence' do
      before do
        stub_member(fs1, sequence: ['1'], rdf_type: ['http://pcdm.org/file-format-types#HOCR'])
        stub_member(fs2, sequence: ['1'], rdf_type: [markup])
        stub_member(fs3, sequence: ['1'], rdf_type: [preservation_file, intermediate_file])
      end

      it 'breaks the tie by arrival order and still picks the IntermediateFile' do
        job.send(:sort_members_and_set_representative, parent_id)

        expect(parent).to have_received(:member_ids=).with([fs1_id, fs2_id, fs3_id])
        expect(parent).to have_received(:representative_id=).with(fs3_id)
        expect(parent).to have_received(:thumbnail_id=).with(fs3_id)
      end
    end

    context 'when no member is an IntermediateFile' do
      before do
        stub_member(fs1, sequence: ['2'], rdf_type: [markup], thumbnail: false)
        stub_member(fs2, sequence: ['1'], rdf_type: [markup], thumbnail: false)
        stub_member(fs3, sequence: ['3'], rdf_type: ['http://pcdm.org/file-format-types#Document'])
      end

      it 'falls back to the first member with a thumbnail derivative' do
        job.send(:sort_members_and_set_representative, parent_id)

        expect(parent).to have_received(:representative_id=).with(fs3_id)
        expect(parent).to have_received(:thumbnail_id=).with(fs3_id)
      end
    end

    context 'when no member is an IntermediateFile or has a thumbnail' do
      before do
        stub_member(fs1, sequence: ['2'], rdf_type: [markup], thumbnail: false)
        stub_member(fs2, sequence: ['1'], rdf_type: [markup], thumbnail: false)
        stub_member(fs3, sequence: ['3'], rdf_type: [markup], thumbnail: false)
      end

      it 'sorts the members and leaves representative and thumbnail unset' do
        job.send(:sort_members_and_set_representative, parent_id)

        expect(parent).to have_received(:member_ids=).with([fs2_id, fs1_id, fs3_id])
        expect(parent).not_to have_received(:representative_id=)
        expect(parent).not_to have_received(:thumbnail_id=)
        expect(persister).to have_received(:save)
      end

      context 'and the members are already in order with a prior choice' do
        let(:parent) do
          double('parent', id: parent_id, member_ids: [fs2_id, fs1_id, fs3_id],
                           representative_id: fs1_id, thumbnail_id: fs1_id)
        end

        it 'leaves the prior choice alone and skips the save' do
          job.send(:sort_members_and_set_representative, parent_id)

          expect(persister).not_to have_received(:save)
        end
      end
    end

    context 'when a member has no usable sequence' do
      before { stub_member(fs2, sequence: nil) }

      it 'sorts the sequenced members first and the unsequenced member last' do
        job.send(:sort_members_and_set_representative, parent_id)

        expect(parent).to have_received(:member_ids=).with([fs1_id, fs3_id, fs2_id])
        expect(parent).to have_received(:representative_id=).with(fs1_id)
        expect(parent).to have_received(:thumbnail_id=).with(fs1_id)
        expect(persister).to have_received(:save)
      end
    end

    context 'when no member has a sequence value' do
      before do
        stub_member(fs1, sequence: [], rdf_type: [markup], thumbnail: false)
        stub_member(fs2, sequence: [])
        stub_member(fs3, sequence: [])
      end

      it 'keeps arrival order and picks the first IntermediateFile' do
        job.send(:sort_members_and_set_representative, parent_id)

        expect(parent).to have_received(:member_ids=).with([fs1_id, fs2_id, fs3_id])
        expect(parent).to have_received(:representative_id=).with(fs2_id)
        expect(parent).to have_received(:thumbnail_id=).with(fs2_id)
        expect(persister).to have_received(:save)
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
