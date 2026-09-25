# frozen_string_literal: true

Dir.chdir(ENV.fetch('HYRAX_DERIVATIVES_PATH'))
$stdin.each_line do |prefix|
  Dir.glob("#{prefix.strip}-*").each { |path| puts "#{File.size(path)}\t#{path}" if File.file?(path) }
end
