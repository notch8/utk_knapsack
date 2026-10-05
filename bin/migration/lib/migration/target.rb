# frozen_string_literal: true

module Migration
  Target = Struct.new(:name, :bucket, :derivatives_bucket, :pod, :local_root, keyword_init: true) do
    class << self
      def for(name)
        bucket, pod = preset(name)
        bucket = ENV.fetch('DST_BUCKET', bucket)
        new(name: name || 'local', bucket:,
            derivatives_bucket: ENV.fetch('DERIVATIVES_BUCKET', name ? bucket : 'utk-poc'),
            pod: ENV.fetch('DST_POD', pod),
            local_root: ENV.fetch('DST_ROOT', File.join(ROOT, 'hyrax-webapp/tmp/derivatives')))
      end

      def preset(name)
        return ['utk-poc', nil] unless name

        cluster = name == 'production' ? 'production' : 'staging'
        ["utk-#{cluster}-repository-#{name}-559021623471",
         "#{ENV.fetch('DEST_CONTEXT', "utk-#{cluster}")}/utk-knapsack-#{name}/deploy/utk-knapsack-#{name}-hyrax"]
      end
    end

    def fill_destination
      pod || local_root
    end
  end
end
