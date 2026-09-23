# frozen_string_literal: true
# Copy one sheet's derivatives from the legacy derivative store to the new one.
#
#   SRC_ROOT=/app/samvera/derivatives DST_ROOT=/app/samvera/hyrax-webapp/tmp/derivatives \
#     ruby copy_derivatives.rb out/ruskin_e2e.csv [--dry-run]
#
# Both roots are read from the environment because they differ per deployment:
# production sets HYRAX_DERIVATIVES_PATH, a local stack leaves it unset and
# Hyrax defaults to tmp/derivatives. Assuming either one silently writes the
# files where nothing will look for them.
require 'csv'
require 'set'
require 'fileutils'

SRC_ROOT = ENV.fetch('SRC_ROOT')
DST_ROOT = ENV.fetch('DST_ROOT')
MANIFEST = ENV.fetch('DERIVATIVE_MANIFEST', File.expand_path('../../tmp/migration/manifests/derivatives_copied.txt', __dir__))

sheet = ARGV.fetch(0)
dry_run = ARGV.include?('--dry-run')

# Hyrax::DerivativePath splits the whole id into pairs; the last pair is the
# filename stem, everything before it is the directory.
def pairtree(id)
  pairs = id.scan(/../)
  [File.join(*pairs[0..-2]), pairs[-1]]
end

FileUtils.mkdir_p(File.dirname(MANIFEST)) unless dry_run
done = File.exist?(MANIFEST) ? Set.new(File.readlines(MANIFEST, chomp: true)) : Set.new

file_set_ids = CSV.read(sheet, headers: true)
                  .select { |row| row['model'] == 'FileSet' }
                  .map { |row| row['id'].to_s.strip }
                  .reject(&:empty?)

todo = file_set_ids.reject { |id| done.include?(id) }
warn "#{sheet}: #{file_set_ids.size} file sets, #{todo.size} not yet copied"

log = File.open(MANIFEST, 'a') unless dry_run
log&.sync = true
copied = files = missing = 0

todo.each do |id|
  dir, stem = pairtree(id)
  sources = Dir.glob(File.join(SRC_ROOT, dir, "#{stem}-*"))
  if sources.empty?
    missing += 1
    next
  end

  unless dry_run
    FileUtils.mkdir_p(File.join(DST_ROOT, dir))
    sources.each do |src|
      FileUtils.cp(src, File.join(DST_ROOT, dir, File.basename(src)))
      files += 1
    end
    log.puts(id)
  end
  copied += 1
end
log&.close

warn format('DONE %d file sets (%d files), %d with no derivatives, %d skipped',
            copied, files, missing, file_set_ids.size - todo.size)
