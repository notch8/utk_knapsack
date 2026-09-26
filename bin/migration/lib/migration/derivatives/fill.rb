# frozen_string_literal: true

module Migration
  module Derivatives
    class Fill < Base
      LABELS = { 'filled' => 'filled', 'present' => 'exists', 'pending' => 'would fill' }.freeze

      def call(ids)
        objects = ids.flat_map { |id| @s3.list_objects_v2(bucket:, prefix: "#{PREFIX}/#{Migration.pairtree(id)}-").contents }
        without = ids.count { |id| objects.none? { |o| o.key.start_with?("#{PREFIX}/#{Migration.pairtree(id)}-") } }
        @target.pod ? from_pod(objects) : locally(objects)
        summarize(format('DONE %d filled, %d already present, %d failed, %d file sets with nothing staged',
                         @tally['filled'], @tally['present'], @failures.size, without),
                  "dry run: #{@tally['pending']} files would be filled into #{@target.fill_destination}")
      end

      private

      def relative(object)
        object.key.delete_prefix("#{PREFIX}/")
      end

      def record(status, path, size, detail = nil)
        @tally[status] += 1
        @failures << "#{path}: #{detail}" if status == 'failed'
        @report.item(LABELS.fetch(status, "FAILED #{detail}"), path, size)
      end

      def from_pod(objects)
        pod = Pod.new(@target.pod, container: 'hyrax')
        objects.each_slice(Integer(ENV.fetch('BATCH', 200))) do |slice|
          sizes = slice.to_h { |o| [relative(o), o.size] }
          jobs = slice.map { |o| "#{presign(:get_object, o.key)}\t#{relative(o)}\t#{o.size}\n" }
          out, err, status = pod.run('download', *(@dry_run ? ['--dry-run'] : []), stdin: jobs.join)
          results = out.lines.grep(/\A(filled|present|pending|failed)\b/)
          raise Stop, "fill in #{pod} failed: #{err[-300..] || err}" unless status.success? && results.size == slice.size

          results.each { |line| record(*parse(line, sizes)) }
        end
      end

      def parse(line, sizes)
        status, path = line.chomp.split("\t", 2)
        [status.split.first, path, sizes[path], status.delete_prefix('failed ')]
      end

      def locally(objects)
        raise Stop, "#{@target.local_root} does not exist" unless Dir.exist?(@target.local_root)

        objects.each { |object| record(*fill_one(object, File.join(@target.local_root, relative(object)))) }
      end

      def fill_one(object, target)
        return ['present', relative(object), object.size] if File.size?(target) == object.size
        return ['pending', relative(object), object.size] if @dry_run

        FileUtils.mkdir_p(File.dirname(target))
        @s3.get_object(bucket:, key: object.key, response_target: "#{target}.part")
        File.rename("#{target}.part", target)
        ['filled', relative(object), object.size]
      rescue StandardError => e
        ['failed', relative(object), object.size, "#{e.class}: #{e.message}"]
      end
    end
  end
end
