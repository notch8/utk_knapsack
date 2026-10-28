# frozen_string_literal: true

require 'open3'

module HykuKnapsack
  class WebPlayable
    PLAYABLE_CODECS = {
      'video/mp4' => { 'video' => %w[h264], 'audio' => %w[aac mp3] },
      'audio/mpeg' => { 'audio' => %w[mp3] },
      'audio/mp3' => { 'audio' => %w[mp3] }
    }.freeze
    PIXEL_FORMATS = %w[yuv420p yuvj420p].freeze

    class << self
      def match?(mime_type, path)
        codecs = PLAYABLE_CODECS[mime_type]
        return false unless codecs

        streams = av_streams(path)
        streams.any? && streams.all? { |stream| playable?(stream, codecs) }
      end

      private

      def playable?(stream, codecs)
        Array(codecs[stream['codec_type']]).include?(stream['codec_name']) &&
          (stream['codec_type'] == 'audio' || PIXEL_FORMATS.include?(stream['pix_fmt']))
      end

      def av_streams(path)
        out, status = Open3.capture2('ffprobe', '-v', 'error', '-show_entries',
                                     'stream=codec_type,codec_name,pix_fmt:stream_disposition=attached_pic',
                                     '-of', 'json', path.to_s)
        return [] unless status.success?

        JSON.parse(out).fetch('streams', []).select do |stream|
          %w[audio video].include?(stream['codec_type']) && stream.dig('disposition', 'attached_pic') != 1
        end
      end
    end
  end
end
