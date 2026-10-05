# frozen_string_literal: true

require 'csv'

cname, email, visibility, name = ARGV
Rails.logger = Logger.new(IO::NULL)
ActiveRecord::Base.logger = Logger.new(IO::NULL)
$stdout.sync = true
say = ->(line) { puts "MARKER #{line}" }
AccountElevator.switch!(cname)

csv = File.join(Dir.tmpdir, "#{name}.csv")
File.write(csv, $stdin.read)
rows = CSV.read(csv, headers: true)
parser = 'Bulkrax::UtkMigrationCsvParser'

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
relationship_jobs = jobs.where(job_class: %w[Bulkrax::ScheduleRelationshipsJob Bulkrax::CreateRelationshipsJob])
retrying_jobs = jobs.where.not(error: nil).where(finished_at: nil)
last = nil
loop do
  importer.reload
  abort "MARKER importer failed: #{importer.error_class} #{importer.status_message}" if importer.error_class.present?

  statuses = importer.entries.map(&:status)
  open = relationship_jobs.where(finished_at: nil).count
  retrying = retrying_jobs.count
  line = "entries #{statuses.size}/#{rows.size} #{statuses.tally} relationship jobs open: #{open}"
  line += " jobs retrying: #{retrying}" if retrying.positive?
  say.call(line) unless line == last
  last = line
  entries_done = statuses.size == rows.size && statuses.none?('Pending')
  break if entries_done && relationship_jobs.exists? && open.zero? && retrying.zero?

  sleep 20
end

children = Hash.new { |hash, key| hash[key] = [] }
rows.each { |row| row['parents'].to_s.split('|').map(&:strip).each { |parent| children[parent] << row } }
identifiers = rows.map { |row| row['source_identifier'] }
collection_id = Hash.new do |hash, identifier|
  hash[identifier] = Hyrax::SolrService.query("bulkrax_identifier_tesim:\"#{identifier}\"", fl: 'id', rows: 1).first&.fetch('id')
end

works = rows.reject { |row| %w[FileSet Collection].include?(row['model']) }
problems = works.filter_map do |row|
  work = Hyrax.query_service.find_by(id: row['id'])
  issues = []
  expected = children[row['source_identifier']].size
  issues << "members #{work.member_ids.size}/#{expected}" unless work.member_ids.size == expected
  row['parents'].to_s.split('|').map(&:strip).reject { |parent| identifiers.include?(parent) }.each do |parent|
    issues << "not in #{parent}" unless work.member_of_collection_ids.map(&:to_s).include?(collection_id[parent])
  end
  issues << 'no thumbnail' if work.thumbnail_id.blank? && expected.positive?
  "#{row['source_identifier']} (#{row['id']}): #{issues.join(', ')}" if issues.any?
rescue Valkyrie::Persistence::ObjectNotFoundError
  "#{row['source_identifier']} (#{row['id']}): missing"
end

importer.entries.select { |entry| entry.status == 'Failed' }.each do |entry|
  say.call("FAILED #{entry.identifier}: #{entry.last_error.to_s[0, 240]}")
end
problems.each { |problem| say.call("PROBLEM #{problem}") }
errors = jobs.discarded.group(:job_class).count
say.call("job errors: #{errors}") if errors.any?
say.call("#{works.size - problems.size} of #{works.size} works landed as the sheet says")
exit(problems.empty? && errors.empty? ? 0 : 1)
