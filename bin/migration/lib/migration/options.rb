# frozen_string_literal: true

require 'optparse'

module Migration
  class Options
    BANNER = 'usage: bin/migration/prepare_sheet tmp/migration/sheets/<name>.csv ' \
             '[--profile NAME] [--dev|--staging|--prod] [--limit N] [--dry-run] [--skip-missing] [--yes]'
    TARGETS = { 'dev' => 'dev', 'staging' => 'staging', 'prod' => 'production' }.freeze

    class << self
      def parse(argv)
        options = { dry_run: false, skip_missing: false }
        parser = build(options)
        parser.parse!(argv)
        abort BANNER if argv.empty?
        options
      rescue OptionParser::ParseError => e
        abort "🛑 #{e.message}\n#{BANNER}"
      end

      private

      def build(options)
        OptionParser.new(BANNER) do |o|
          TARGETS.each { |flag, name| o.on("--#{flag}") { choose_target(options, name) } }
          o.on('--limit N', OptionParser::DecimalInteger) { |n| options[:limit] = positive(n) }
          o.on('--dry-run') { options[:dry_run] = true }
          o.on('--skip-missing') { options[:skip_missing] = true }
          o.on('-y', '--yes', 'skip the confirmation prompt') { options[:yes] = true }
          o.on('--profile NAME', 'AWS profile, as with the aws CLI') { |name| ENV['AWS_PROFILE'] = name }
        end
      end

      def choose_target(options, name)
        abort '🛑 Pick one of --dev, --staging, --prod' if options[:target]
        options[:target] = name
      end

      def positive(number)
        abort '🛑 --limit takes a positive number of works' unless number.positive?
        number
      end
    end
  end
end
