# frozen_string_literal: true
require 'csv'
require 'fileutils'
require 'aws-sdk-s3'

DST_ROOT = ENV.fetch('DST_ROOT')
BUCKET = ENV.fetch('DERIVATIVES_BUCKET', 'utk-poc')
REGION = ENV.fetch('AWS_REGION', 'us-east-2')
PREFIX = 'derivatives'

def pairtree(id)
  pairs = id.scan(/../)
  File.join(*pairs[0..-2], pairs[-1])
end

sheet = ARGV.fetch(0)
dry_run = ARGV.include?('--dry-run')
abort "#{DST_ROOT} does not exist" unless Dir.exist?(DST_ROOT)

ids = CSV.read(sheet, headers: true)
         .select { |row| row['model'] == 'FileSet' }
         .map { |row| row['id'].to_s.strip }
         .reject(&:empty?)

s3 = Aws::S3::Client.new(region: REGION)
filled = present = pending = 0
without = 0

ids.each do |id|
  objects = s3.list_objects_v2(bucket: BUCKET, prefix: "#{PREFIX}/#{pairtree(id)}-").contents
  without += 1 if objects.empty?
  objects.each do |object|
    target = File.join(DST_ROOT, object.key.delete_prefix("#{PREFIX}/"))
    if File.size?(target) == object.size
      present += 1
      next
    end
    pending += 1
    next if dry_run

    FileUtils.mkdir_p(File.dirname(target))
    s3.get_object(bucket: BUCKET, key: object.key, response_target: "#{target}.part")
    File.rename("#{target}.part", target)
    filled += 1
  end
end

warn format('DONE %d filled, %d already present, %d file sets with nothing staged', filled, present, without)
warn "dry run: #{pending} files would be filled into #{DST_ROOT}" if dry_run
