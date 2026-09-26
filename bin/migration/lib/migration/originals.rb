# frozen_string_literal: true

module Migration
  class Originals
    SRC = ENV.fetch('SRC_BUCKET', 'besties-fcrepo')
    SINGLE_COPY_LIMIT = 5 * 1024**3
    LABELS = { copied: 'copied', present: 'exists', pending: 'would copy', missing: 'MISSING', failed: 'FAILED' }.freeze

    attr_reader :missing

    def initialize(target, report, dry_run: false)
      @target = target
      @report = report
      @dry_run = dry_run
      @client = Aws::S3::Client.new(region: ENV.fetch('AWS_REGION', 'us-east-2'))
      @source = Aws::S3::Client.new(region: ENV.fetch('SRC_REGION', 'us-west-2'))
      @missing = []
      @failures = []
    end

    def copy(rows)
      jobs = jobs_for(rows)
      tally = Hash.new(0)
      each_in_parallel(jobs) { |job, outcome, detail| record(tally, jobs.size, job, outcome, detail) }
      summarize(tally)
      @failures.empty?
    end

    private

    def jobs_for(rows)
      rows.select { |row| row['model'] == 'FileSet' && row['id'] && !row['sha1'].to_s.empty? }
          .map { |row| [Bulkrax::UtkMigrationObjectKey.for(file_set_id: row['id'], sha1: row['sha1']), row['sha1'], row['file_size'].to_i] }
    end

    def each_in_parallel(jobs)
      mutex = Mutex.new
      queue = Queue.new
      jobs.each { |job| queue << job }
      queue.close
      threads = Integer(ENV.fetch('THREADS', 8))
      raise Stop, 'THREADS must be at least 1' if threads < 1

      Array.new(threads) do
        Thread.new do
          while (job = queue.pop)
            outcome, detail = attempt(*job)
            mutex.synchronize { yield job, outcome, detail }
          end
        end
      end.each(&:join)
    end

    def record(tally, total, job, outcome, detail)
      key, _, size = job
      tally[outcome] += 1
      @missing << key.split('/').first if outcome == :missing
      @failures << "#{key}: #{detail}" if outcome == :failed
      @report.item("[#{tally.values.sum.to_s.rjust(total.to_s.size)}/#{total}] #{LABELS[outcome].ljust(10)}", key, size)
    end

    def summarize(tally)
      @report.failures(@missing.map { |id| "file set #{id}" }, "originals missing from #{SRC}")
      @report.failures(@failures)
      warn format('DONE %d copied, %d already in s3://%s, %d missing, %d failed',
                  tally[:copied], tally[:present], @target.bucket, tally[:missing], tally[:failed])
      warn "dry run: #{tally[:pending]} objects would be copied" if @dry_run
    end

    def attempt(key, sha1, size)
      return :present if copied?(key, size)
      return(in_source?(sha1) ? :pending : :missing) if @dry_run

      if size > SINGLE_COPY_LIMIT
        Aws::S3::Object.new(@target.bucket, key, client: @client)
                       .copy_from("#{SRC}/#{sha1}", multipart_copy: true, copy_source_region: ENV.fetch('SRC_REGION', 'us-west-2'))
      else
        @client.copy_object(bucket: @target.bucket, key:, copy_source: "#{SRC}/#{sha1}")
      end
      :copied
    rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
      :missing
    rescue StandardError => e
      [:failed, "#{e.class}: #{e.message}"]
    end

    def copied?(key, size)
      @client.head_object(bucket: @target.bucket, key:).content_length == size
    rescue Aws::S3::Errors::NotFound
      false
    end

    def in_source?(sha1)
      @source.head_object(bucket: SRC, key: sha1)
      true
    rescue Aws::S3::Errors::NotFound
      false
    end
  end
end
