# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0: answer a Range request by reading only the requested bytes, a seek on disk or
# a ranged GET on S3, instead of reading from byte 0, and cap each response so an open-ended range
# never loads a whole file into memory
module HykuKnapsack
  module ValkyrieRangeDownloadsDecorator
    MAX_RANGE_BYTES = 8 * 1024 * 1024

    private

    def prepare_range_headers_valkyrie(file:)
      from, to = requested_range(file)
      last = file.size - 1
      return unsatisfiable_range(file) if from.nil? || from > last || (to && to < from)

      to = [to || last, last, from + MAX_RANGE_BYTES - 1].min
      length = to - from + 1
      response.headers['Content-Range'] = "bytes #{from}-#{to}/#{file.size}"
      response.headers['Content-Length'] = length.to_s
      self.status = 206
      [from, length]
    end

    def requested_range(file)
      match = /\Abytes=(\d*)-(\d*)\z/.match(request.headers['Range'].to_s)
      return if match.nil? || (match[1].empty? && match[2].empty?)
      return [[file.size - match[2].to_i, 0].max, file.size - 1] if match[1].empty?

      [match[1].to_i, match[2].presence&.to_i]
    end

    def unsatisfiable_range(file)
      response.headers['Content-Range'] = "bytes */#{file.size}"
      response.headers['Content-Length'] = '0'
      self.status = 416
      [0, 0]
    end

    def send_range_valkyrie(file:)
      from, length = prepare_range_headers_valkyrie(file:)
      return ''.b if length.zero?
      return read_range_from_shrine(file.io, from, length) if in_s3?(file.io)

      file.io.seek(from)
      file.io.read(length)
    ensure
      file.io.close if in_s3?(file.io)
    end

    def read_range_from_shrine(io, from, length)
      ranged = io.shrine.open(io.id, rewindable: false, range: "bytes=#{from}-#{from + length - 1}")
      ranged.read
    ensure
      ranged&.close
    end

    def in_s3?(io)
      io.is_a?(Valkyrie::Storage::Shrine::DelayedDownload)
    end
  end
end

Hyrax::DownloadsController.prepend(HykuKnapsack::ValkyrieRangeDownloadsDecorator)
