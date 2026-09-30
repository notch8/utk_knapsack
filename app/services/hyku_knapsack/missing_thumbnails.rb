# frozen_string_literal: true

module HykuKnapsack
  class MissingThumbnails
    Candidate = Struct.new(:file_set_id, :original, keyword_init: true)
    BATCH_SIZE = 200

    def self.call(**options)
      new(**options).call
    end

    def initialize(dry_run: false, limit: nil, io: $stdout)
      @dry_run = dry_run
      @limit = limit
      @io = io
    end

    def call
      tally = Hash.new(0)
      candidates.each do |candidate|
        break if limit && tally.values.sum >= limit

        io.puts("#{candidate.file_set_id} #{candidate.original.mime_type}#{' characterize first' unless derivable?(candidate.original)}")
        tally[candidate.original.mime_type] += 1
        enqueue(candidate) unless dry_run
      end
      report(tally)
      tally.values.sum
    end

    def candidates
      return to_enum(:candidates) unless block_given?

      Hyrax.custom_queries.find_file_sets_without_thumbnail.each_slice(BATCH_SIZE) do |file_sets|
        originals = originals_for(file_sets)
        file_sets.each do |file_set|
          original = originals[file_set.id.to_s]
          next unless original && eligible?(file_set, original)

          yield Candidate.new(file_set_id: file_set.id.to_s, original:)
        end
      end
    end

    private

    attr_reader :dry_run, :limit, :io

    def originals_for(file_sets)
      ids = file_sets.flat_map(&:file_ids)
      Hyrax.custom_queries.find_many_file_metadata_by_ids(ids:).select(&:original_file?).index_by { |file| file.file_set_id.to_s }
    end

    def eligible?(file_set, original)
      ThumbnailCandidate.match?(file_set, original)
    end

    def enqueue(candidate)
      if derivable?(candidate.original)
        ValkyrieCreateDerivativesJob.perform_later(candidate.file_set_id, candidate.original.id.to_s)
      else
        UtkMigrationCharacterizationJob.perform_later(candidate.original.id.to_s)
      end
    end

    def derivable?(original)
      derivative_services.any? { |service| service.new(original).valid? }
    end

    def derivative_services
      return Hyrax.config.derivative_services if Hyrax.config.respond_to?(:derivative_services)

      Hyrax::DerivativeService.services
    end

    def report(tally)
      verb = dry_run ? 'would be enqueued' : 'enqueued'
      io.puts("#{tally.values.sum} file sets #{verb}#{tally.map { |mime, n| " #{mime}=#{n}" }.join}")
    end
  end
end
