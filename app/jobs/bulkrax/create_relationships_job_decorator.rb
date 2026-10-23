# frozen_string_literal: true

# OVERRIDE Bulkrax 10.0.0: after the relationship pass assembles a work's
# member_ids, rewrite them in sequence order and set representative_id /
# thumbnail_id to the member the legacy app would have shown, or thumbnail_id
# to a member UTK supplied as its ThumbnailImage. The migration
# factory bypasses the transaction that normally does this. Then reindex the
# work's file sets, which were indexed before they had a parent and so lack
# the `is_page_of_ssim` IIIF search filters on. Queue the ingest of each file
# set created from an upload as soon as the pass first attaches it, so
# characterization and derivatives, OCR included, run with a parent.
module Bulkrax
  module CreateRelationshipsJobDecorator
    private

    def process_parent_as_work(parent_record:, parent_identifier:)
      super
      return unless @parent_record_members_added

      ActiveRecord::Base.uncached do
        conditionally_acquire_lock_for(parent_record.id.to_s) do
          sort_members_and_set_representative(parent_record.id)
        end
        reindex_file_sets(parent_record.id)
      end
    end

    def add_to_work(relationship:, parent_record:, ability:)
      _child_entry, child_record = find_record(relationship.child_id, @importer_run_id)
      already_member = child_record && Hyrax.query_service.find_by(id: parent_record.id).member_ids.include?(child_record.id)
      updated_parent = super
      ingest_held_uploads(child_record) unless already_member || child_record.try(:file_ids).present?
      updated_parent
    end

    def ingest_held_uploads(child_record)
      Hyrax::UploadedFile.where(file_set_uri: child_record.id.to_s).find_each { |upload| ValkyrieIngestJob.perform_later(upload) }
    end

    def reindex_file_sets(parent_id)
      parent = Hyrax.query_service.find_by(id: parent_id)
      Bulkrax.object_factory.update_index_for_file_sets_of(resource: parent)
    end

    def sort_members_and_set_representative(parent_id)
      parent = Hyrax.query_service.find_by(id: parent_id)
      members = Hyrax.query_service.find_members(resource: parent).to_a
      return if members.empty?

      sorted = sort_by_sequence(members)
      representative_id = representative_for(sorted)&.id
      thumbnail_id = sorted.find { |member| thumbnail_image?(member) }&.id || representative_id
      updates = { member_ids: sorted.map(&:id), representative_id:, thumbnail_id: }.compact
      return if updates.all? { |attribute, value| parent.public_send(attribute) == value }

      updates.each { |attribute, value| parent.public_send("#{attribute}=", value) }
      saved_parent = Hyrax.persister.save(resource: parent)
      Bulkrax.object_factory.update_index(resources: [saved_parent])
    end

    def sort_by_sequence(members)
      members.each_with_index.sort_by do |member, arrival|
        key = HykuKnapsack::SequenceSortKey.call(member.try(:sequence))
        [key ? 0 : 1, key || 0, arrival]
      end.map(&:first)
    end

    def representative_for(members)
      candidates = members.reject { |member| thumbnail_image?(member) }
      candidates.find { |member| intermediate_file?(member) } || first_with_thumbnail(candidates)
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

      Hyrax.query_service.find_many_by_ids(ids: file_ids).filter_map { |file| file.file_set_id if file.thumbnail_file? }
    end

    def intermediate_file?(member)
      HykuKnapsack::PcdmUse.intermediate_file?(member.try(:rdf_type))
    end

    def thumbnail_image?(member)
      HykuKnapsack::PcdmUse.thumbnail_image?(member.try(:rdf_type))
    end
  end
end

Bulkrax::CreateRelationshipsJob.prepend(Bulkrax::CreateRelationshipsJobDecorator)
