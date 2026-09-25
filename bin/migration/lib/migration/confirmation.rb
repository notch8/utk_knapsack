# frozen_string_literal: true

module Migration
  class Confirmation
    PLACES = { 'local' => [:green], 'production' => %i[bold red] }.freeze

    def initialize(options, target, sheet, file)
      @options = options
      @target = target
      @sheet = sheet
      @file = file
    end

    def ask!
      return if @options[:yes]
      abort '🛑 No terminal to confirm on; pass --yes to run without the prompt.' unless $stdin.tty?

      puts
      print "#{mode} of #{scope} from #{paint(@file, :bold, :orange)} on #{place}#{profile}#{skip}. #{question} "
      abort 'Cancelled.' unless $stdin.gets.to_s.strip.downcase == answer
      puts
    end

    private

    def paint(text, *styles)
      Report.paint(text, *styles)
    end

    def mode
      @options[:dry_run] ? paint('Dry run', :cyan) : paint('Real run', :bold, :yellow)
    end

    def scope
      total = @sheet.work_count
      count = [@options[:limit] || total, total].min
      return "the #{paint(count == 1 ? 'first work' : "first #{count} works", :magenta)}" if @options[:limit]

      total == 1 ? "the #{paint('only work', :magenta)}" : paint("all #{total} works", :magenta)
    end

    def place
      paint(@target.name == 'production' ? 'prod' : @target.name, *PLACES.fetch(@target.name, [:yellow]))
    end

    def profile
      ENV['AWS_PROFILE'] ? " as #{paint(ENV['AWS_PROFILE'], :blue)}" : ''
    end

    def skip
      @options[:skip_missing] ? ', setting aside works legacy cannot supply' : ''
    end

    def answer
      @target.name == 'production' && !@options[:dry_run] ? 'prod' : 'y'
    end

    def question
      answer == 'prod' ? 'Type prod to proceed:' : 'Proceed? (y/N)'
    end
  end
end
