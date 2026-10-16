# frozen_string_literal: true

module Migration
  class Progress
    ALREADY = 'done in an earlier run; --recheck to check every item again'

    def initialize(path, target, read: true, write: true)
      @path = path
      @target = target.to_h
      @write = write
      @steps = read ? load : {}
      save unless read
    end

    def key!(step, work)
      key = Digest::SHA1.hexdigest(JSON.generate([@target, work]))
      @steps[step] = { 'key' => key, 'done' => false, 'cursor' => 0 } unless @steps.dig(step, 'key') == key
    end

    def run(step)
      return warn(ALREADY) if done?(step)

      done!(step) unless yield == false
    end

    def done?(step)
      @steps.dig(step, 'done') == true
    end

    def done!(step)
      @steps[step]['done'] = true
      save
    end

    def cursor(step)
      @steps.dig(step, 'cursor') || 0
    end

    def advance!(step, count)
      @steps[step]['cursor'] = cursor(step) + count
      save
    end

    private

    def load
      File.exist?(@path) ? JSON.parse(File.read(@path)) : {}
    rescue JSON::ParserError
      {}
    end

    def save
      return unless @write

      File.write("#{@path}.tmp", JSON.generate(@steps))
      File.rename("#{@path}.tmp", @path)
    end
  end
end
