# frozen_string_literal: true

require 'csv'

cname, email, mode = ARGV
Rails.logger = Logger.new(IO::NULL)
ActiveRecord::Base.logger = Logger.new(IO::NULL)
$stdout.sync = true
say = ->(line) { puts "MARKER #{line}" }
AccountElevator.switch!(cname)
user = User.find_by!(email:)
apply = mode == 'apply'

rows = CSV.parse($stdin.read, headers: true).select { |row| row['model'] == 'FileSet' }
done = 0
rows.each do |row|
  identifier = row['source_identifier']
  parent = row['parents'].to_s.split('|').map(&:strip).first
  query = "bulkrax_identifier_tesim:\"#{identifier}\""
  docs = Hyrax::SolrService.query(query, fq: 'has_model_ssim:FileSet', fl: 'id,bulkrax_identifier_tesim', rows: 5)
                           .select { |doc| Array(doc['bulkrax_identifier_tesim']).include?(identifier) }
  next if docs.empty?
  next say.call("SKIP #{identifier}: #{docs.size} matches") unless docs.one?

  file_set = Hyrax.query_service.find_by(id: docs.first['id'])
  work = Hyrax.custom_queries.find_parent_work(resource: file_set)
  next say.call("SKIP #{identifier}: parent is #{Array(work&.bulkrax_identifier).inspect}, sheet says #{parent}") unless
    Array(work&.bulkrax_identifier).include?(parent)

  original = file_set.original_file
  detail = "#{identifier} #{file_set.id} from #{parent} (#{original&.mime_type}, #{Array(original&.recorded_size).first} bytes)"
  if apply
    Hyrax::Transactions::Container['file_set.destroy']
      .with_step_args('file_set.remove_from_work' => { user: }, 'file_set.delete' => { user: })
      .call(file_set).value!
    say.call("deleted #{detail}")
  else
    say.call("would delete #{detail}")
  end
  done += 1
end
say.call("#{apply ? 'deleted' : 'would delete'} #{done} of #{rows.size} file sets in the sheet")
