# frozen_string_literal: true
require 'base64'
require 'csv'
require 'open3'
require 'aws-sdk-s3'

CONTEXT = ENV.fetch('UTK_CONTEXT', 'r2-besties')
NAMESPACE = ENV.fetch('UTK_NAMESPACE', 'utk-hyku-production')
DEPLOYMENT = ENV.fetch('UTK_DEPLOYMENT', 'deploy/utk-hyku-production-hyrax')
CONTAINER = ENV.fetch('UTK_CONTAINER', 'hyrax')
TENANT = ENV.fetch('UTK_TENANT', '56e0eb81-c2d5-4d5d-9171-b251bf7299a4')
CNAME = ENV.fetch('UTK_CNAME', 'digitalcollections.lib.utk.edu')
BUCKET = ENV.fetch('DERIVATIVES_BUCKET', 'utk-poc')
REGION = ENV.fetch('AWS_REGION', 'us-east-2')
PREFIX = 'derivatives'
BATCH = Integer(ENV.fetch('BATCH', 50))

UPLOADER = <<~'RUBY'
  require 'net/http'
  require 'uri'
  $stdin.each_line do |line|
    url, path = line.chomp.split("\t", 2)
    uri = URI(url)
    File.open(path, 'rb') do |io|
      req = Net::HTTP::Put.new(uri)
      req['Content-Length'] = io.size.to_s
      req.body_stream = io
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 600) { |h| h.request(req) }
      puts "#{res.code}\t#{path}"
    end
  end
RUBY

def in_pod(script, stdin: nil)
  Open3.capture2e('kubectl', '--context', CONTEXT, '-n', NAMESPACE, 'exec', '-i', DEPLOYMENT, '-c', CONTAINER,
                  '--', 'bash', '-lc', script, stdin_data: stdin.to_s)
end

def verify_tenant!
  query = "${SOLR_URL%/}/#{TENANT}/select?q=generic_type_sim:Work&rows=1&fl=account_cname_tesim&wt=json"
  out, = in_pod(%(curl -sf "#{query}"))
  abort "Could not reach UTK's tenant (#{CNAME}) through context #{CONTEXT}" unless out.include?(CNAME)
end

def remote_root
  out, status = in_pod('printf %s "$HYRAX_DERIVATIVES_PATH"')
  abort "could not read the pod's derivatives path: #{out[0, 300]}" unless status.success?
  out.strip.tap { |path| abort 'the pod sets no HYRAX_DERIVATIVES_PATH' if path.empty? }
end

def pairtree(id)
  pairs = id.scan(/../)
  File.join(*pairs[0..-2], pairs[-1])
end

def staged?(s3, key, size)
  s3.head_object(bucket: BUCKET, key:).content_length == size
rescue Aws::S3::Errors::NotFound
  false
end

sheet = ARGV.fetch(0)
dry_run = ARGV.include?('--dry-run')

verify_tenant!
root = remote_root
warn "legacy derivatives: #{root}"
warn "bucket:             s3://#{BUCKET}/#{PREFIX}/"

ids = CSV.read(sheet, headers: true)
         .select { |row| row['model'] == 'FileSet' }
         .map { |row| row['id'].to_s.strip }
         .reject(&:empty?)

s3 = Aws::S3::Client.new(region: REGION)
presigner = Aws::S3::Presigner.new(client: s3)
staged = skipped = failed = pending = 0
without = ids.size

ids.each_slice(BATCH) do |slice|
  listing, status = in_pod(%(cd #{root} || exit 1
                             while read p; do for f in ${p}-*; do [ -f "$f" ] || continue; stat -c '%s %n' "$f"; done; done),
                           stdin: "#{slice.map { |id| pairtree(id) }.join("\n")}\n")
  abort "listing failed: #{listing[0, 300]}" unless status.success?

  files = listing.lines.map { |l| l.chomp.split(' ', 2) }.map { |size, path| [path, Integer(size)] }
  without -= slice.count { |id| files.any? { |path, _| path.start_with?("#{pairtree(id)}-") } }
  todo = files.reject { |path, size| staged?(s3, "#{PREFIX}/#{path}", size) }
  skipped += files.size - todo.size
  pending += todo.size
  next if todo.empty? || dry_run

  jobs = todo.map do |path, _|
    "#{presigner.presigned_url(:put_object, bucket: BUCKET, key: "#{PREFIX}/#{path}", expires_in: 3600)}\t#{path}"
  end
  out, = in_pod(%(echo #{Base64.strict_encode64(UPLOADER)} | base64 -d > /tmp/stage_uploader.rb
                  cd #{root} && ruby /tmp/stage_uploader.rb; rm -f /tmp/stage_uploader.rb),
                stdin: "#{jobs.join("\n")}\n")

  todo.each do |path, size|
    if staged?(s3, "#{PREFIX}/#{path}", size)
      staged += 1
    else
      failed += 1
      warn "  FAILED #{path}: #{out.lines.find { |l| l.end_with?("#{path}\n") }&.split("\t")&.first || 'no response'}"
    end
  end
  warn "  #{staged + skipped} files staged so far"
end

warn format('DONE %d staged, %d already staged, %d failed, %d file sets with no derivatives',
            staged, skipped, failed, without)
warn "dry run: #{pending} files would be staged" if dry_run
exit(failed.zero? ? 0 : 1)
