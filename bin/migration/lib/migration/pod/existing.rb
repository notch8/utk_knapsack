# frozen_string_literal: true

Rails.logger = Logger.new(IO::NULL)
ActiveRecord::Base.logger = Logger.new(IO::NULL)
AccountElevator.switch!(ARGV[0])

$stdin.each_line.map(&:strip).reject(&:empty?).each_slice(200) do |slice|
  query = slice.map { |id| %("#{id.gsub('"', '\"')}") }.join(' OR ')
  Hyrax::SolrService.query("bulkrax_identifier_tesim:(#{query})", fl: 'bulkrax_identifier_tesim,has_model_ssim', rows: 2000).each do |doc|
    (Array(doc['bulkrax_identifier_tesim']) & slice).each { |identifier| puts "MARKER #{identifier}\t#{Array(doc['has_model_ssim']).first}" }
  end
end
