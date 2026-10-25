# frozen_string_literal: true

module Migration
  class Pod
    SCRIPTS = File.join(__dir__, 'pod')
    TIMEOUT = Integer(ENV.fetch('POD_TIMEOUT', 1800))
    ATTEMPTS = 2
    SLOTS = '/tmp/utk-migration-legacy-slots'

    class Hung < Stop; end

    class << self
      def legacy
        new([ENV.fetch('UTK_CONTEXT', 'r2-besties'), ENV.fetch('UTK_NAMESPACE', 'utk-hyku-production'),
             ENV.fetch('UTK_DEPLOYMENT', 'deploy/utk-hyku-production-hyrax')].join('/'),
            slots: Integer(ENV.fetch('LEGACY_SLOTS', 2)))
      end
    end

    def initialize(spec, container: ENV.fetch('UTK_CONTAINER', 'hyrax'), slots: nil, slot_dir: SLOTS)
      @context, @namespace, @deployment = spec.split('/', 3)
      @container = container
      @slots = slots
      @slot_dir = slot_dir
    end

    def to_s
      [@context, @namespace, @deployment].join('/')
    end

    def run(script, *args, stdin: '', ruby: 'ruby', &block)
      code = Base64.strict_encode64(File.read(File.join(SCRIPTS, "#{script}.rb")))
      path = "/tmp/migration-#{script}-#{Process.pid}.rb"
      command = "#{cd}echo #{code} | base64 -d > #{path}; #{ruby} #{path} #{args.shelljoin}; s=$?; rm -f #{path}; exit $s"
      with_slot do
        stdin = stdin.call if stdin.respond_to?(:call)
        next capture(script, command, stdin) unless block

        Open3.popen2e(*prefix, 'bash', '-lc', command, chdir: ROOT) do |input, output, wait|
          input.write(stdin)
          input.close
          output.each_line(&block)
          wait.value
        end
      end
    end

    private

    def with_slot
      return yield unless @slots

      FileUtils.mkdir_p(@slot_dir)
      waited = false
      loop do
        @slots.times do |n|
          File.open(File.join(@slot_dir, n.to_s), File::RDWR | File::CREAT) do |lock|
            return yield if lock.flock(File::LOCK_EX | File::LOCK_NB)
          end
        end
        warn "waiting for a slot on #{self}, all #{@slots} in use" unless waited
        waited = true
        sleep 5
      end
    end

    def capture(script, command, stdin, attempt = 1)
      Open3.popen3(*prefix, 'bash', '-lc', command, chdir: ROOT) do |input, output, error, wait|
        feed(input, stdin)
        out = Thread.new { output.read }
        err = Thread.new { error.read }
        return [out.value, err.value, wait.value] if wait.join(TIMEOUT)

        kill(wait.pid)
        [wait, out, err].each(&:join)
        raise Hung, "#{script} on #{self} ran past #{TIMEOUT}s, #{attempt} times" if attempt == ATTEMPTS

        warn "#{script} on #{self} ran past #{TIMEOUT}s, retrying"
      end
      capture(script, command, stdin, attempt + 1)
    end

    def kill(pid)
      Process.kill('KILL', pid)
    rescue Errno::ESRCH
      nil
    end

    def feed(input, stdin)
      Thread.new do
        input.write(stdin)
      rescue Errno::EPIPE, IOError
        nil
      ensure
        input.close unless input.closed?
      end
    end

    def prefix
      ['kubectl', '--context', @context, '-n', @namespace, 'exec', '-i', @deployment, '-c', @container, '--']
    end

    def cd
      ''
    end
  end

  class LocalApp < Pod
    def to_s
      'local'
    end

    private

    def prefix
      %w[docker compose exec -T web]
    end

    def cd
      'cd /app/samvera/hyrax-webapp; '
    end
  end
end
