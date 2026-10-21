# frozen_string_literal: true

module Migration
  module Derivatives
    class Stage < Base
      attr_reader :without

      def call(ids, legacy, progress = nil)
        @without = []
        @failed_paths = []
        resumed = progress&.cursor('stage').to_i
        warn "resuming after #{resumed} file sets done in an earlier run; the counts below cover this run" if resumed.positive?
        ids.drop(resumed).each_slice(Integer(ENV.fetch('BATCH', 50))) do |slice|
          stage_slice(slice, legacy)
          progress&.advance!('stage', slice.size) if @failures.empty?
        end
        summarize(format('DONE %d staged, %d already staged, %d failed, %d file sets with no derivatives',
                         @tally[:staged], @tally[:present], @failures.size, @without.size),
                  "dry run: #{@tally[:pending]} files would be staged")
      end

      def missing(rows)
        ids = without.to_set
        models = rows.to_h { |row| [row['source_identifier'], row['model']] }
        rows.select { |row| ids.include?(row['id']) && expected?(row, models[row['parents']]) }
      end

      def waive!(rows)
        raise Stop if unregenerated_failures(rows).any?

        warn 'Every failed derivative belongs to a file set left without a thumbnail, which the import regenerates; continuing'
      end

      def unregenerated_failures(rows)
        models = rows.to_h { |row| [row['source_identifier'], row['model']] }
        prefixes = rows.select { |row| row['model'] == 'FileSet' && expected?(row, models[row['parents']]) }
                       .map { |row| "#{Migration.pairtree(row['id'])}-" }
        @failed_paths.reject do |path|
          prefix = prefixes.find { |candidate| path.start_with?(candidate) }
          thumbnail = prefix && @failed_paths.find { |failed| failed.start_with?("#{prefix}thumbnail.") }
          thumbnail && !present?(thumbnail)
        end
      end

      private

      def stage_slice(slice, legacy)
        files = list(slice, legacy)
        @without.concat(slice.reject { |id| files.any? { |path, _| path.start_with?("#{Migration.pairtree(id)}-") } })
        present, todo = files.partition { |path, size| staged?(path, size) }
        present.each { |path, size| @report.item('exists', path, size) }
        @tally[:present] += present.size
        @dry_run ? plan(todo) : upload(todo, legacy)
      end

      def expected?(row, parent_model)
        parent_model == 'Pdf' ||
          row['rdf_type'].to_s.split('|').any? { |type| type.strip.split(%r{[#/:]}).last.to_s.casecmp?('IntermediateFile') }
      end

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

        out, = legacy.run('upload', stdin: -> { files.map { |path, _| "#{presign(:put_object, "#{PREFIX}/#{path}")}\t#{path}\n" }.join })
        files.each do |path, size|
          next record(path, size) if staged?(path, size)

          @failed_paths << path
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

      def present?(path)
        @s3.head_object(bucket:, key: "#{PREFIX}/#{path}")
        true
      rescue Aws::S3::Errors::NotFound
        false
      end
    end
  end
end
