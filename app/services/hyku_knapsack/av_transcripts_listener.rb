# frozen_string_literal: true

module HykuKnapsack
  class AvTranscriptsListener
    def on_object_membership_updated(event)
      resource = event[:object]
      ActiveRecord::Base.uncached do
        work = resource.try(:file_set?) ? Hyrax.custom_queries.find_parent_work(resource:) : resource
        link(work) if work.is_a?(Audio) || work.is_a?(Video)
      end
    rescue StandardError => e
      Hyrax.logger.error("#{self.class} could not link transcripts for #{resource&.id}: #{e.class} #{e.message}")
    end

    private

    def link(work)
      file_sets = Hyrax.custom_queries.find_child_file_sets(resource: work).to_a
      transcripts, media = file_sets.partition { |file_set| PcdmUse.transcript?(file_set.try(:rdf_type)) }
      transcript_ids = transcripts.map { |transcript| transcript.id.to_s }

      media.each do |file_set|
        next if file_set.file_ids.blank?
        next unless file_set.respond_to?(:transcript_ids=)

        linked = Array(file_set.transcript_ids).map(&:to_s)
        next if (transcript_ids - linked).empty?

        file_set.transcript_ids = linked | transcript_ids
        Hyrax.index_adapter.save(resource: Hyrax.persister.save(resource: file_set))
      end
    end
  end
end
