# Copy one sheet's derivatives out of the legacy application into the local
# derivative store.
#
#   ruby pull_derivatives.rb out/ruskin_e2e.csv [--dry-run]
#
# Both derivative roots are discovered rather than assumed: the legacy one from
# the running pod's `HYRAX_DERIVATIVES_PATH`, the local one from
# `Hyrax.config.derivatives_path`. They differ, and writing to the wrong one
# looks exactly like success until nothing can find a thumbnail.
require 'csv'
require 'set'
require 'fileutils'
require 'open3'
require 'tempfile'

NAMESPACE = ENV.fetch('UTK_NAMESPACE', 'utk-hyku-production')
DEPLOYMENT = ENV.fetch('UTK_DEPLOYMENT', 'deploy/utk-hyku-production-hyrax')
CONTAINER = ENV.fetch('UTK_CONTAINER', 'hyrax')
TENANT = ENV.fetch('UTK_TENANT', '56e0eb81-c2d5-4d5d-9171-b251bf7299a4')
CNAME = ENV.fetch('UTK_CNAME', 'digitalcollections.lib.utk.edu')
MANIFEST = ENV.fetch('DERIVATIVE_MANIFEST', File.expand_path('../../tmp/migration/manifests/derivatives.txt', __dir__))

def kubectl(*args, stdin: nil)
  Open3.capture2e('kubectl', '-n', NAMESPACE, *args, stdin_data: stdin.to_s)
end

def in_pod(script, stdin: nil)
  kubectl('exec', '-i', DEPLOYMENT, '-c', CONTAINER, '--', 'bash', '-lc', script, stdin:)
end

# The legacy deployment is shared with unrelated tenants, so reaching the
# cluster is not the same as reaching UTK's data.
def verify_tenant!
  query = "${SOLR_URL%/}/#{TENANT}/select?q=generic_type_sim:Work&rows=1&fl=account_cname_tesim&wt=json"
  out, = in_pod(%(curl -sf "#{query}"))
  return if out.include?(CNAME)

  context, = Open3.capture2('kubectl', 'config', 'current-context')
  abort <<~MSG
    Could not reach UTK's tenant (#{CNAME}).
    Current kubectl context: #{context.strip.inspect}
    Switch to the context with the #{NAMESPACE} namespace and retry.
  MSG
end

def remote_root
  out, = in_pod('printf %s "$HYRAX_DERIVATIVES_PATH"')
  out.strip.tap { |path| abort 'the pod sets no HYRAX_DERIVATIVES_PATH' if path.empty? }
end

def local_root
  out, = Open3.capture2e('docker', 'compose', 'exec', '-T', 'web', 'bash', '-lc',
                         'cd /app/samvera && ./bin/rails runner "print Hyrax.config.derivatives_path"')
  out.lines.last.to_s.strip.tap { |path| abort "could not read the local derivatives path: #{out}" if path.empty? }
end

# Confirms each file set actually has files under the local root, so the
# manifest can never claim work that did not happen.
def verify_landed(local, ids)
  checks = ids.map { |id| dir, stem = pairtree(id); "#{local}/#{dir}/#{stem}" }
  out, = Open3.capture2e('docker', 'compose', 'exec', '-T', 'web', 'bash', '-lc',
                         checks.map { |p| %(ls #{p}-* >/dev/null 2>&1 && echo #{p}) }.join('; '))
  ids.select.with_index { |_id, i| out.include?(checks[i]) }
end

def pairtree(id)
  pairs = id.scan(/../)
  [File.join(*pairs[0..-2]), pairs[-1]]
end

sheet = ARGV.fetch(0)
dry_run = ARGV.include?('--dry-run')
# The manifest records what was copied, not what is still on disk. `--recheck`
# ignores it, for when the local store has been cleared out from under it.
recheck = ARGV.include?('--recheck')

verify_tenant!
remote = remote_root
local = local_root
warn "legacy derivatives: #{remote}"
warn "local derivatives:  #{local}"

FileUtils.mkdir_p(File.dirname(MANIFEST))
done = File.exist?(MANIFEST) ? Set.new(File.readlines(MANIFEST, chomp: true)) : Set.new

ids = CSV.read(sheet, headers: true)
         .select { |row| row['model'] == 'FileSet' }
         .map { |row| row['id'].to_s.strip }
         .reject { |id| id.empty? || (!recheck && done.include?(id)) }
warn "#{sheet}: #{ids.size} file sets to pull"
exit 0 if ids.empty? || dry_run

log = File.open(MANIFEST, 'a')
log.sync = true
pulled = files = missing = 0

# One file set at a time so an interrupted run resumes cleanly: the manifest
# entry is written only after that file set's files are on disk.
ids.each_slice(Integer(ENV.fetch('BATCH', 25))) do |slice|
  prefixes = slice.map { |id| dir, stem = pairtree(id); "#{dir}/#{stem}" }
  # Ask first which of these actually have derivatives: a file set with none is
  # ordinary (a MODS record has no thumbnail), not a failure to copy.
  listing, = in_pod(%(cd #{remote} || exit 1
                      while read p; do ls ${p}-* 2>/dev/null; done),
                    stdin: "#{prefixes.join("\n")}\n")
  present = slice.select.with_index { |_id, i| listing.include?("#{prefixes[i]}-") }
  missing += slice.size - present.size
  next if present.empty?

  tar, status = in_pod(
    %(cd #{remote} || exit 1
      while read p; do ls ${p}-* 2>/dev/null; done > /tmp/flist
      tar cf - -T /tmp/flist),
    stdin: "#{present.map { |id| dir, stem = pairtree(id); "#{dir}/#{stem}" }.join("\n")}\n"
  )
  abort "kubectl exec failed: #{tar[0, 300]}" unless status.success?

  # `local` is a path inside the web container, so the extract runs there too.
  # The archive goes via a file rather than stdin_data: Open3 mangles binary
  # written through a pipe to `docker compose exec`, which silently extracts
  # nothing while still exiting zero.
  archive = Tempfile.new(['derivatives', '.tar'])
  archive.binmode
  archive.write(tar)
  archive.close
  extracted = system("docker compose exec -T web bash -lc " \
                     "'mkdir -p #{local} && tar xf - -C #{local}' < #{archive.path}")
  archive.unlink
  abort 'extract into the web container failed' unless extracted

  # Written only once the files are on disk, so an interrupted run resumes
  # rather than skipping work it never did.
  landed = verify_landed(local, present)
  abort "extract reported success but #{present.size - landed.size} file sets have no files" \
    unless landed.size == present.size

  landed.each { |id| log.puts(id) }
  pulled += landed.size
  warn "  #{pulled}/#{ids.size}"
end
log.close

warn format('DONE %d file sets, %d with no derivatives', pulled, missing)
