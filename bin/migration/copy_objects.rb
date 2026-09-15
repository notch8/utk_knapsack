# Copy one sheet's originals into the destination bucket, server side.
#
#   ruby copy_objects.rb out/ruskin_e2e.csv [--dry-run]
#
# The manifest is global rather than per sheet: 98,310 file sets share a sha1
# with another file set and those pairs cross collection boundaries, so a
# per-sheet log would re-copy them and could not tell a re-copy from a first
# copy on resume.
require 'csv'; require 'set'; require 'fileutils'; require 'aws-sdk-s3'

SRC = ENV.fetch('SRC_BUCKET', 'besties-fcrepo')
DST = ENV.fetch('DST_BUCKET', 'utk-poc')
REGION = ENV.fetch('AWS_REGION', 'us-east-2')
MANIFEST = ENV.fetch('COPY_MANIFEST', File.expand_path('../../tmp/migration/manifests/objects.txt', __dir__))
THREADS = Integer(ENV.fetch('THREADS', 8))

sheet = ARGV.fetch(0)
dry_run = ARGV.include?('--dry-run')

FileUtils.mkdir_p(File.dirname(MANIFEST))
done = File.exist?(MANIFEST) ? Set.new(File.readlines(MANIFEST, chomp: true)) : Set.new
warn "manifest holds #{done.size} objects already copied"

digests = CSV.read(sheet, headers: true)
             .select { |row| row['model'] == 'FileSet' }
             .map { |row| row['sha1'].to_s.strip }
             .reject(&:empty?)
             .uniq

todo = digests.reject { |d| done.include?(d) }
warn "#{sheet}: #{digests.size} distinct objects, #{todo.size} to copy"
exit 0 if todo.empty? || dry_run

client = Aws::S3::Client.new(region: REGION)
log = File.open(MANIFEST, 'a')
log.sync = true
mutex = Mutex.new
copied = failed = 0
queue = Queue.new
todo.each { |d| queue << d }

workers = Array.new(THREADS) do
  Thread.new do
    while (digest = queue.pop(true) rescue nil)
      begin
        client.copy_object(bucket: DST, key: digest, copy_source: "#{SRC}/#{digest}")
        mutex.synchronize { log.puts(digest); copied += 1 }
      rescue Aws::S3::Errors::ServiceError => e
        mutex.synchronize { failed += 1; warn "  FAILED #{digest}: #{e.class}" }
      end
    end
  end
end
workers.each(&:join)
log.close

warn format('DONE %d copied, %d failed, %d skipped', copied, failed, digests.size - todo.size)
exit(failed.zero? ? 0 : 1)
