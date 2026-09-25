# frozen_string_literal: true

# OVERRIDE Bulkrax 9.5.1: after the relationship pass assembles a work's
# member_ids, rewrite them in sequence order and set representative_id /
# thumbnail_id to the member the legacy app would have shown. The migration
# factory bypasses the transaction that normally does this.
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

      sorted = sort_by_sequence(members)
      sorted_ids = sorted.map(&:id)
      representative_id = representative_for(sorted)&.id
      return if already_ordered?(parent, sorted_ids, representative_id)

      parent.member_ids = sorted_ids
      if representative_id
        parent.representative_id = representative_id
        parent.thumbnail_id = representative_id
      end
      saved_parent = Hyrax.persister.save(resource: parent)
      Bulkrax.object_factory.update_index(resources: [saved_parent])
    end

    def already_ordered?(parent, sorted_ids, representative_id)
      return false unless parent.member_ids == sorted_ids
      return true if representative_id.nil?

      parent.representative_id == representative_id &&
        parent.thumbnail_id == representative_id
    end

    def sort_by_sequence(members)
      members.each_with_index.sort_by do |member, arrival|
        key = HykuKnapsack::SequenceSortKey.call(member.try(:sequence))
        [key ? 0 : 1, key || 0, arrival]
      end.map(&:first)
    end

    def representative_for(members)
      members.find { |member| intermediate_file?(member) } || first_with_thumbnail(members)
    end

    def first_with_thumbnail(members)
      file_sets_with_thumbnail = file_set_ids_with_thumbnail(members)
      members.find do |member|
        member.file_set? ? file_sets_with_thumbnail.include?(member.id) : member.try(:thumbnail_id).present?
      end
    end

    def file_set_ids_with_thumbnail(members)
      file_ids = members.select(&:file_set?).flat_map(&:file_ids)
      return [] if file_ids.empty?

      Hyrax.query_service.find_many_by_ids(ids: file_ids).select(&:thumbnail_file?).map(&:file_set_id)
    end

    def intermediate_file?(member)
      fragment = Hyrax::FileMetadata::Use::INTERMEDIATE_FILE.fragment
      Array(member.try(:rdf_type)).any? { |type| type.to_s.split(%r{[#/:]}).last.to_s.casecmp?(fragment) }
    end
  end
end

Bulkrax::CreateRelationshipsJob.prepend(Bulkrax::CreateRelationshipsJobDecorator)
