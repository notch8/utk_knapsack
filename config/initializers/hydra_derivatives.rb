# frozen_string_literal: true

video = Hydra::Derivatives::Processors::Video::Processor.config
video.mpeg4.codec += ' -preset veryfast' unless video.mpeg4.codec.include?('-preset')
video.video_attributes = '-g 30 -crf 23 -movflags +faststart'
