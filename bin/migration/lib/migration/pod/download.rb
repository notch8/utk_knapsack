# frozen_string_literal: true

require 'fileutils'
require 'net/http'
require 'uri'

root = ENV.fetch('HYRAX_DERIVATIVES_PATH')
dry_run = ARGV.include?('--dry-run')
$stdin.each_line do |line|
  url, path, size = line.chomp.split("\t", 3)
  target = File.join(root, path)
  next puts("present\t#{path}") if File.size?(target) == Integer(size)
  next puts("pending\t#{path}") if dry_run

  FileUtils.mkdir_p(File.dirname(target))
  uri = URI(url)
  Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 600) do |http|
    http.request(Net::HTTP::Get.new(uri)) do |response|
      next puts("failed #{response.code}\t#{path}") unless response.code == '200'

      File.open("#{target}.part", 'wb') { |file| response.read_body { |chunk| file.write(chunk) } }
      File.rename("#{target}.part", target)
      puts "filled\t#{path}"
    end
  end
end
