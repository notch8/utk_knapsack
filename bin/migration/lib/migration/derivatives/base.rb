# frozen_string_literal: true

module Migration
  module Derivatives
    class Base
      def initialize(target, report, dry_run: false)
        @target = target
        @report = report
        @dry_run = dry_run
        @s3 = Aws::S3::Client.new(region: ENV.fetch('AWS_REGION', 'us-east-2'))
        @presigner = Aws::S3::Presigner.new(client: @s3)
        @tally = Hash.new(0)
        @failures = []
      end

      private

      def bucket
        @target.derivatives_bucket
      end

      def presign(method, key)
        @presigner.presigned_url(method, bucket:, key:, expires_in: 3600)
      end

      def summarize(done, pending)
        @report.failures(@failures)
        warn done
        warn pending if @dry_run
        @failures.empty?
      end
    end
  end
end
