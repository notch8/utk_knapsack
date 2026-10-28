# frozen_string_literal: true

# OVERRIDE valkyrie-shrine 1.1.0: size an S3 file with a HEAD request instead of starting a full GET,
# and close only a download that was actually opened
module HykuKnapsack
  module ShrineDelayedDownloadDecorator
    def size
      @file ? @file.size : (@size ||= shrine.object(id).content_length)
    end

    def close
      @file&.close
    end
  end
end

Valkyrie::Storage::Shrine::DelayedDownload.prepend(HykuKnapsack::ShrineDelayedDownloadDecorator)
