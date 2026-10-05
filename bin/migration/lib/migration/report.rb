# frozen_string_literal: true

module Migration
  class Stop < StandardError; end

  class Report
    UNITS = %w[B KB MB GB TB].freeze
    COLORS = { bold: 1, red: 31, green: 32, yellow: 33, blue: 34, magenta: 35, cyan: 36, orange: '38;5;208' }.freeze

    class << self
      def paint(text, *styles)
        return text unless $stdout.tty? && !ENV.key?('NO_COLOR')

        "\e[#{styles.map { |style| COLORS.fetch(style) }.join(';')}m#{text}\e[0m"
      end

      def human(bytes)
        exp = bytes.positive? ? [(Math.log(bytes) / Math.log(1024)).floor, UNITS.size - 1].min : 0
        format('%.1f %s', bytes.to_f / (1024**exp), UNITS[exp])
      end
    end

    def step(title)
      puts "\n▶️  #{title}"
      yield
      puts "✅ #{title}"
    rescue Stop => e
      warn e.message unless e.message == e.class.name
      puts "🛑 Stopped at: #{title}. Fix what it reported above, then run again."
      exit 1
    end

    def item(status, what, size = nil)
      warn format('  %-12s %s%s', status, what, size ? " (#{self.class.human(size)})" : '')
    end

    def failures(list, noun = 'failed')
      return if list.empty?

      warn "#{list.size} #{noun}:"
      list.each { |entry| warn "  - #{entry}" }
    end
  end
end
