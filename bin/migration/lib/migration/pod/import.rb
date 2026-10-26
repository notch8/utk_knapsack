# frozen_string_literal: true

require 'csv'

cname, email, visibility, name, parser, again = ARGV
Rails.logger = Logger.new(IO::NULL)
ActiveRecord::Base.logger = Logger.new(IO::NULL)
$stdout.sync = true
say = ->(line) { puts "MARKER #{line}" }
AccountElevator.switch!(cname)

csv = File.join(Dir.tmpdir, "#{name}.csv")
File.write(csv, $stdin.read)
rows = CSV.read(csv, headers: true)

recent = Bulkrax::Importer.where(name:).where('created_at > ?', 1.day.ago).pluck(:id)
abort "MARKER 🛑 importer #{recent.join(', ')} already imported #{name} in the last day; pass --again to import it again" if recent.any? && again != 'again'

importer = Bulkrax::Importer.new(
  name:,
  admin_set_id: Hyrax::AdminSetCreateService.find_or_create_default_admin_set.id.to_s,
  user: User.find_by!(email:),
  frequency: 'PT0S',
  parser_klass: parser,
  parser_fields: { 'visibility' => visibility, 'rights_statement' => '', 'override_rights_statement' => '0',
                   'file_style' => 'Upload a File', 'entry_statuses' => [''], 'update_files' => true },
  field_mapping: Bulkrax.field_mappings[parser]
)
importer.save!
upload = ActionDispatch::Http::UploadedFile.new(tempfile: File.open(csv), filename: "#{name}.csv")
importer[:parser_fields]['import_file_path'] = importer.parser.write_import_file(upload)
importer.save!
Bulkrax::ImporterJob.perform_later(importer.id)
say.call("importer #{importer.id} (#{name}) queued with #{rows.size} rows")

jobs = GoodJob::Job.where('created_at >= ?', importer.created_at)
                   .where("serialized_params->>'tenant' = ?", Apartment::Tenant.current)
own_jobs = lambda do
  run_id = importer.last_run&.id.to_s
  jobs.where(job_class: 'Bulkrax::ScheduleRelationshipsJob').where("serialized_params->'arguments'->0->>'importer_id' = ?", importer.id.to_s)
      .or(jobs.where(job_class: 'Bulkrax::CreateRelationshipsJob').where("serialized_params->'arguments'->0->>'importer_run_id' = ?", run_id))
      .or(jobs.where(job_class: %w[Bulkrax::ImportWorkJob Bulkrax::ImportFileSetJob Bulkrax::ImportCollectionJob])
              .where("serialized_params->'arguments'->>1 = ?", run_id))
end
ingest_jobs = jobs.where(job_class: 'ValkyrieIngestJob', finished_at: nil)
last = nil
loop do
  importer.reload
  abort "MARKER importer failed: #{importer.error_class} #{importer.status_message}" if importer.error_class.present?

  relationship_jobs = own_jobs.call.where(job_class: %w[Bulkrax::ScheduleRelationshipsJob Bulkrax::CreateRelationshipsJob])
  retrying_jobs = own_jobs.call.where.not(error: nil).where(finished_at: nil)

  statuses = importer.entries.map(&:status)
  open = relationship_jobs.where(finished_at: nil).count
  retrying = retrying_jobs.count
  line = "entries #{statuses.size}/#{rows.size} #{statuses.tally} relationship jobs open: #{open}"
  line += " jobs retrying: #{retrying}" if retrying.positive?
  say.call(line) unless line == last
  last = line
  entries_done = statuses.size == rows.size && statuses.none?('Pending')
  break if entries_done && relationship_jobs.exists? && open.zero? && retrying.zero? && !ingest_jobs.exists?

  sleep 20
end

children = Hash.new { |hash, key| hash[key] = [] }
rows.each { |row| row['parents'].to_s.split('|').map(&:strip).each { |parent| children[parent] << row } }
identifiers = rows.map { |row| row['source_identifier'] }
id_for = Hash.new do |hash, identifier|
  docs = Hyrax::SolrService.query("bulkrax_identifier_tesim:\"#{identifier}\"", fl: 'id,bulkrax_identifier_tesim', rows: 5)
  hash[identifier] = docs.find { |doc| Array(doc['bulkrax_identifier_tesim']).include?(identifier) }&.fetch('id')
end
regular_csv = parser == 'Bulkrax::CsvParser'
rows.each { |row| row['id'] ||= id_for[row['source_identifier']] }

works = rows.reject { |row| %w[FileSet Collection].include?(row['model']) }
problems = works.filter_map do |row|
  next "#{row['source_identifier']}: missing" unless row['id']

  work = Hyrax.query_service.find_by(id: row['id'])
  issues = []
  expected = children[row['source_identifier']].size
  if regular_csv
    absent = children[row['source_identifier']].reject { |child| work.member_ids.map(&:to_s).include?(child['id'].to_s) }
    issues << "members missing #{absent.map { |child| child['source_identifier'] }.first(5).inspect}" if absent.any?
    sequence_of = children[row['source_identifier']].select { |child| child['sequence'].to_s.match?(/\A\d+\z/) }
                                                    .to_h { |child| [child['id'].to_s, child['sequence'].to_i] }
    order = work.member_ids.filter_map { |member_id| sequence_of[member_id.to_s] }
    issues << 'members out of sequence' unless order == order.sort
  else
    issues << "members #{work.member_ids.size}/#{expected}" unless work.member_ids.size == expected
  end
  row['parents'].to_s.split('|').map(&:strip).reject { |parent| identifiers.include?(parent) }.each do |parent|
    issues << "not in #{parent}" unless work.member_of_collection_ids.map(&:to_s).include?(id_for[parent])
  end
  issues << 'no thumbnail' if !regular_csv && work.thumbnail_id.blank? && expected.positive?
  "#{row['source_identifier']} (#{row['id']}): #{issues.join(', ')}" if issues.any?
rescue Valkyrie::Persistence::ObjectNotFoundError
  "#{row['source_identifier']} (#{row['id']}): missing"
end

file_sets = regular_csv ? rows.select { |row| row['model'] == 'FileSet' } : []
file_set_problems = file_sets.filter_map do |row|
  next "#{row['source_identifier']}: missing" unless row['id']

  file_set = Hyrax.query_service.find_by(id: row['id'])
  original = file_set.original_file
  parent = row['parents'].to_s.split('|').map(&:strip).first
  issues = []
  issues << "not in #{parent}" unless Array(Hyrax.custom_queries.find_parent_work(resource: file_set)&.bulkrax_identifier).include?(parent)
  issues << 'no file' unless Array(original&.recorded_size).first.to_i.positive?
  issues << "visibility #{file_set.visibility}, sheet says #{row['visibility']}" if row['visibility'].present? && file_set.visibility != row['visibility']
  issues << "an HTML page (#{original.mime_type})" if original&.mime_type.to_s.include?('html')
  "#{row['source_identifier']} (#{row['id']}): #{issues.join(', ')}" if issues.any?
rescue Valkyrie::Persistence::ObjectNotFoundError
  "#{row['source_identifier']} (#{row['id']}): missing"
end

failed = importer.entries.select { |entry| entry.status == 'Failed' }
failed.each do |entry|
  say.call("FAILED #{entry.identifier}: #{entry.last_error.to_s[0, 240]}")
end
(problems + file_set_problems).each { |problem| say.call("PROBLEM #{problem}") }
errors = own_jobs.call.discarded.group(:job_class).count
say.call("job errors: #{errors}") if errors.any?
say.call("#{works.size - problems.size} of #{works.size} works landed as the sheet says")
say.call("#{file_sets.size - file_set_problems.size} of #{file_sets.size} file sets landed as the sheet says") if regular_csv
exit(failed.empty? && problems.empty? && file_set_problems.empty? && errors.empty? ? 0 : 1)
