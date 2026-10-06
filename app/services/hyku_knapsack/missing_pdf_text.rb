# frozen_string_literal: true

module HykuKnapsack
  class MissingPdfText
    ORIGINAL = { pcdm_use: [{ '@id' => Hyrax::FileMetadata::Use::ORIGINAL_FILE.to_s }] }.to_json.freeze
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
      count = 0
      candidates.each do |original|
        break if limit && count >= limit

        io.puts("#{original.file_set_id} #{original.id}")
        count += 1
        ExtractPdfTextJob.perform_later(original.id.to_s) unless dry_run
      end
      io.puts("#{count} file sets #{dry_run ? 'would be enqueued' : 'enqueued'}")
      count
    end

    def candidates
      return to_enum(:candidates) unless block_given?

      originals.each do |original|
        next unless DerivativeCandidate.pdf?(original)

        file_set = Hyrax.query_service.find_by(id: original.file_set_id)
        next unless PdfTextExtractor.needed?(file_set, original:)

        yield original
      rescue Valkyrie::Persistence::ObjectNotFoundError
        next
      end
    end

    private

    attr_reader :dry_run, :limit, :io

    def originals
      return to_enum(:originals) unless block_given?

      factory = Hyrax.query_service.resource_factory
      factory.orm_class.where(internal_resource: 'Hyrax::FileMetadata').where('metadata @> ?::jsonb', ORIGINAL)
             .find_each(batch_size: BATCH_SIZE) { |row| yield factory.to_resource(object: row) }
    end
  end
end
