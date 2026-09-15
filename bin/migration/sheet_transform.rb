# Turn a client-supplied Bulkrax sheet into a migration-ready one.
#
#   ruby sheet_transform.rb collections_acwiley.csv lookup.jsonl out.csv
#
# Adds the production UUID and file pointer by joining on source_identifier,
# collapses the flat relator columns into the `creators` compound, and drops
# remote_files so nothing is re-downloaded.
require 'csv'
require 'json'
require 'yaml'

PROFILE = YAML.safe_load_file(File.expand_path('../../config/metadata_profiles/m3_profile.yaml', __dir__))
RENAMED_MODELS = { 'Image' => 'StillImage' }.freeze

# A column is a role column when its name, minus an optional `utk_` prefix,
# names a term in one of the two role authorities.  The file decides the
# compound and the term's `id` is the value the form validates against.
AUTHORITIES = File.expand_path('../../config/authorities', __dir__)
ROLE_FOR_COLUMN = %w[creator contributor].each_with_object({}) do |compound, acc|
  YAML.safe_load_file(File.join(AUTHORITIES, "#{compound}_roles.yml")).fetch('terms').each do |term|
    column = term['id'].downcase.gsub(/[^a-z0-9]+/, '_')
    acc[column] = acc["utk_#{column}"] = [compound, term['id']]
  end
end.freeze

def unwrap(value)
  text = value.to_s
  return [value] unless text.start_with?('[') && text.end_with?(']')
  parsed = JSON.parse(text)
  parsed.is_a?(Array) ? parsed.map(&:to_s) : [value]
rescue JSON::ParserError
  [value]
end

# Batches fetched from an Islandora datastream URL with no filename inherited
# Ruby's Tempfile name: OBJ20240609-1-ho71ae. The stem is the datastream name,
# which is what every other batch stored. Only strip when the stem looks like a
# datastream (all caps), so a real filename is never touched.
TEMPFILE_NAME = /\A([A-Z][A-Z_-]*)\d{8}-\d+-[a-z0-9]+\z/

def strip_tempfile_suffix(value)
  match = TEMPFILE_NAME.match(value.to_s)
  match ? match[1] : value
end

def split_values(cell)
  cell.to_s.split('|').flat_map { |v| unwrap(v.strip) }.map(&:strip).reject(&:empty?)
end

sheet, lookup_path, out_path = ARGV.fetch(0), ARGV.fetch(1), ARGV.fetch(2)

lookup = {}
File.foreach(lookup_path) do |line|
  doc = JSON.parse(line)
  Array(doc['bulkrax_identifier_tesim']).each { |identifier| lookup[identifier] ||= doc }
end
warn "lookup entries: #{lookup.size}"

NON_WORK_MODELS = %w[Collection FileSet].freeze

# The profile declares minimums, but nothing below the edit form enforces them:
# Valkyrie resources carry no validations and the migration factory saves them
# directly, so a missing required value persists silently. This is the only
# place it can be caught.
PROFILE_MODEL = { 'FileSet' => 'Hyrax::FileSet', 'Collection' => 'DigitalCollection' }.freeze

REQUIRED_BY_MODEL = PROFILE['properties'].each_with_object(Hash.new { |h, k| h[k] = [] }) do |(name, config), acc|
  cardinality = config['cardinality']
  next unless cardinality.is_a?(Hash) && cardinality['minimum'].to_i >= 1

  available = config['available_on']
  available = available['class'] if available.is_a?(Hash)
  Array(available).each { |model| acc[model] << name }
end

rows = CSV.read(sheet, headers: true)
out_rows = []
unmatched = []
max_agents = Hash.new(0)

rows.each do |row|
  source_id = row['source_identifier']
  found = lookup[source_id]
  unmatched << source_id if found.nil?

  out = { 'source_identifier' => source_id,
          'id' => found && found['id'],
          'model' => RENAMED_MODELS.fetch(row['model'].to_s, row['model']),
          'parents' => row['parents'] }

  # The sheets carry no primary_identifier, which the profile requires on every
  # work type. On production dcterms:identifier, which is what the property maps
  # to, holds the Islandora PID: the same value as source_identifier.
  out['primary_identifier'] = source_id unless NON_WORK_MODELS.include?(out['model'])

  # creators and contributors compounds, from the flat relator columns
  agents = { 'creator' => [], 'contributor' => [] }
  row.headers.compact.each do |header|
    compound, role = ROLE_FOR_COLUMN[header]
    next if compound.nil?
    split_values(row[header]).each { |value| agents[compound] << { name: value, role: role } }
  end
  agents.each do |compound, entries|
    max_agents[compound] = [max_agents[compound], entries.size].max
    entries.each_with_index do |entry, i|
      out["#{compound}_name_#{i + 1}"] = entry[:name]
      out["#{compound}_role_#{i + 1}"] = entry[:role]
    end
  end

  # everything else passes through, minus what we replaced
  row.headers.compact.each do |header|
    next if %w[source_identifier model parents remote_files].include?(header)
    next if ROLE_FOR_COLUMN.key?(header)
    values = split_values(row[header])
    out[header] = values.join(' | ') unless values.empty?
  end

  if out['model'] == 'FileSet' && found
    out['sha1'] = Array(found['digest_ssim']).first.to_s.sub('urn:sha1:', '')
    out['mime_type'] = found['mime_type_ssi']
    out['file_size'] = found['file_size_lts']
    out['original_filename'] = strip_tempfile_suffix(Array(found['label_tesim']).first)
  end

  out_rows << out
end

headers = out_rows.flat_map(&:keys).uniq
CSV.open(out_path, 'w') do |csv|
  csv << headers
  out_rows.each { |r| csv << headers.map { |h| r[h] } }
end

warn "#{out_path}: #{out_rows.size} rows, #{headers.size} columns, max #{max_agents["creator"]} creators, #{max_agents["contributor"]} contributors/row"
warn "unmatched source_identifiers: #{unmatched.size} #{unmatched.first(5).inspect}"

missing = out_rows.flat_map do |row|
  model = PROFILE_MODEL.fetch(row['model'].to_s, row['model'].to_s)
  REQUIRED_BY_MODEL[model].reject { |property| row[property].to_s.strip.empty? }
                          .then { |present| REQUIRED_BY_MODEL[model] - present }
                          .map { |property| [row['source_identifier'], model, property] }
end

if missing.empty?
  warn 'required properties: all rows satisfy the profile minimums'
else
  warn "MISSING REQUIRED: #{missing.size} across #{missing.map(&:first).uniq.size} rows"
  missing.first(20).each { |id, model, property| warn "  #{id} (#{model}) missing #{property}" }
end

# A file set with no digest cannot be created: there is nothing to point at.
# Across the tenant 20,878 are in that state, and 280 of them are `OBJ`, which
# means a work migrating with no preservation master. Surfacing them per sheet
# is cheaper than reading them back out of failed entries.
file_set_rows = out_rows.select { |row| row['model'] == 'FileSet' }
no_digest = file_set_rows.reject { |row| row['sha1'].to_s.strip.length.positive? }

if no_digest.empty?
  warn "file sets: #{file_set_rows.size}, all carry a digest"
else
  by_label = no_digest.group_by { |row| row['original_filename'].to_s.empty? ? '(none)' : row['original_filename'] }
  warn "NO DIGEST: #{no_digest.size} of #{file_set_rows.size} file sets cannot be created"
  by_label.sort_by { |_, rows| -rows.size }.each { |label, rows| warn "  #{label}: #{rows.size}" }
  originals = by_label.fetch('OBJ', [])
  warn "  #{originals.size} are OBJ, so that many works arrive with no preservation master" if originals.any?
end

unknown_roles = out_rows.first&.keys.to_a.select do |header|
  header.start_with?('utk_') && !PROFILE['properties'].key?(header) &&
    !PROFILE['properties'].key?(header.delete_prefix('utk_'))
end
warn "UNKNOWN ROLE COLUMNS, passed through untouched: #{unknown_roles.join(', ')}" if unknown_roles&.any?

duplicate_digests = file_set_rows.map { |row| row['sha1'] }.compact.tally.select { |_, n| n > 1 }
warn "shared digests within this sheet: #{duplicate_digests.size}" if duplicate_digests.any?

