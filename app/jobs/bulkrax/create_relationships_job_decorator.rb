# frozen_string_literal: true

# OVERRIDE Bulkrax 9.5.1: after the relationship pass assembles a work's
# member_ids, rewrite them in sequence order and set representative_id /
# thumbnail_id to the first member. The migration factory bypasses the
# transaction that normally does this.
module Bulkrax
  module CreateRelationshipsJobDecorator
    private

    def process_parent_as_work(parent_record:, parent_identifier:)
      super
      return unless @parent_record_members_added

      conditionally_acquire_lock_for(parent_record.id.to_s) do
        sort_members_and_set_representative(parent_record.id)
      end
    end

    def sort_members_and_set_representative(parent_id)
      parent = Hyrax.query_service.find_by(id: parent_id)
      members = Hyrax.query_service.find_members(resource: parent).to_a
      return if members.empty?

      sorted_ids = sort_by_sequence(members) || parent.member_ids
      return if sorted_ids.empty?

      first_id = sorted_ids.first
      return if already_ordered?(parent, sorted_ids, first_id)

      parent.member_ids = sorted_ids
      parent.representative_id = first_id
      parent.thumbnail_id = first_id
      saved_parent = Hyrax.persister.save(resource: parent)
      Bulkrax.object_factory.update_index(resources: [saved_parent])
    end

    def already_ordered?(parent, sorted_ids, first_id)
      parent.member_ids == sorted_ids &&
        parent.representative_id == first_id &&
        parent.thumbnail_id == first_id
    end

    def sort_by_sequence(members)
      keyed = members.map do |member|
        key = HykuKnapsack::SequenceSortKey.call(member.try(:sequence))
        return nil if key.nil?

        [key, member.id]
      end

      keyed.sort_by(&:first).map(&:last)
    end
  end
end

Bulkrax::CreateRelationshipsJob.prepend(Bulkrax::CreateRelationshipsJobDecorator)
