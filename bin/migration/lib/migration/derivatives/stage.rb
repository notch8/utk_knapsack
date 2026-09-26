# frozen_string_literal: true

module Migration
  module Derivatives
    class Stage < Base
      def call(ids, legacy)
        ids.each_slice(Integer(ENV.fetch('BATCH', 50))) do |slice|
          files = list(slice, legacy)
          @tally[:with] += slice.count { |id| files.any? { |path, _| path.start_with?("#{Migration.pairtree(id)}-") } }
          present, todo = files.partition { |path, size| staged?(path, size) }
          present.each { |path, size| @report.item('exists', path, size) }
          @tally[:present] += present.size
          @dry_run ? plan(todo) : upload(todo, legacy)
        end
        summarize(format('DONE %d staged, %d already staged, %d failed, %d file sets with no derivatives',
                         @tally[:staged], @tally[:present], @failures.size, ids.size - @tally[:with]),
                  "dry run: #{@tally[:pending]} files would be staged")
      end

      private

      def plan(files)
        files.each { |path, size| @report.item('would stage', path, size) }
        @tally[:pending] += files.size
      end

      def list(slice, legacy)
        out, err, status = legacy.run('list', stdin: slice.map { |id| "#{Migration.pairtree(id)}\n" }.join)
        raise Stop, "listing in #{legacy} failed: #{err[-300..] || err}" unless status.success?

        out.lines.map { |line| line.chomp.split("\t", 2) }.map { |size, path| [path, Integer(size)] }
      end

      def upload(files, legacy)
        return if files.empty?

        out, = legacy.run('upload', stdin: files.map { |path, _| "#{presign(:put_object, "#{PREFIX}/#{path}")}\t#{path}\n" }.join)
        files.each do |path, size|
          next record(path, size) if staged?(path, size)

          @failures << "#{path}: #{out[/^(\S+)\t#{Regexp.escape(path)}$/, 1] || 'no response'}"
          @report.item('FAILED', @failures.last)
        end
      end

      def record(path, size)
        @tally[:staged] += 1
        @report.item('staged', path, size)
      end

      def staged?(path, size)
        @s3.head_object(bucket:, key: "#{PREFIX}/#{path}").content_length == size
      rescue Aws::S3::Errors::NotFound
        false
      end
    end
  end
end
