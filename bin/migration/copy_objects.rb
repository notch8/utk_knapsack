# frozen_string_literal: true
# Copy one sheet's originals into the destination bucket, server side.
#
#   ruby copy_objects.rb out/ruskin_e2e.csv [--dry-run]
require 'csv'
require 'set'
require 'fileutils'
require 'aws-sdk-s3'
require_relative '../../app/factories/bulkrax/utk_migration_object_key'

SRC = ENV.fetch('SRC_BUCKET', 'besties-fcrepo')
DST = ENV.fetch('DST_BUCKET', 'utk-poc')
REGION = ENV.fetch('AWS_REGION', 'us-east-2')
MANIFEST = ENV.fetch('COPY_MANIFEST', File.expand_path("../../tmp/migration/manifests/objects-#{DST}.txt", __dir__))
THREADS = Integer(ENV.fetch('THREADS', 8))
abort 'THREADS must be at least 1' if THREADS < 1

sheet = ARGV.fetch(0)
dry_run = ARGV.include?('--dry-run')

FileUtils.mkdir_p(File.dirname(MANIFEST)) unless dry_run
done = File.exist?(MANIFEST) ? Set.new(File.readlines(MANIFEST, chomp: true)) : Set.new
warn "manifest holds #{done.size} objects already copied"

copies = CSV.read(sheet, headers: true)
            .select { |row| row['model'] == 'FileSet' }
            .map { |row| [row['id'].to_s.strip, row['sha1'].to_s.strip] }
            .reject { |id, sha1| id.empty? || sha1.empty? }
            .to_h { |id, sha1| [Bulkrax::UtkMigrationObjectKey.for(file_set_id: id, sha1:), sha1] }

todo = copies.reject { |key, _| done.include?(key) }.to_a
warn "#{sheet}: #{copies.size} objects, #{todo.size} to copy"
exit 0 if todo.empty? || dry_run

client = Aws::S3::Client.new(region: REGION)
log = File.open(MANIFEST, 'a')
log.sync = true
mutex = Mutex.new
copied = failed = 0
queue = Queue.new
todo.each { |pair| queue << pair }
queue.close

workers = Array.new(THREADS) do
  Thread.new do
    while (job = queue.pop)
      key, sha1 = job
      begin
        client.copy_object(bucket: DST, key:, copy_source: "#{SRC}/#{sha1}")
        mutex.synchronize do
          log.puts(key)
          copied += 1
        end
      rescue StandardError => e
        mutex.synchronize do
          failed += 1
          warn "  FAILED #{key} from #{sha1}: #{e.class}"
        end
      end
    end
  end
end
workers.each(&:join)
log.close

warn format('DONE %d copied, %d failed, %d skipped', copied, failed, copies.size - todo.size)
exit(failed.zero? ? 0 : 1)
