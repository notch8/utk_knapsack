# frozen_string_literal: true

module Migration
  class Pod
    SCRIPTS = File.join(__dir__, 'pod')

    class << self
      def legacy
        new([ENV.fetch('UTK_CONTEXT', 'r2-besties'), ENV.fetch('UTK_NAMESPACE', 'utk-hyku-production'),
             ENV.fetch('UTK_DEPLOYMENT', 'deploy/utk-hyku-production-hyrax')].join('/'))
      end
    end

    def initialize(spec, container: ENV.fetch('UTK_CONTAINER', 'hyrax'))
      @context, @namespace, @deployment = spec.split('/', 3)
      @container = container
    end

    def to_s
      [@context, @namespace, @deployment].join('/')
    end

    def run(script, *args, stdin: '')
      code = Base64.strict_encode64(File.read(File.join(SCRIPTS, "#{script}.rb")))
      path = "/tmp/migration-#{script}-#{Process.pid}.rb"
      command = "echo #{code} | base64 -d > #{path}; ruby #{path} #{args.shelljoin}; s=$?; rm -f #{path}; exit $s"
      Open3.capture3('kubectl', '--context', @context, '-n', @namespace, 'exec', '-i', @deployment,
                     '-c', @container, '--', 'bash', '-lc', command, stdin_data: stdin)
    end
  end
end
