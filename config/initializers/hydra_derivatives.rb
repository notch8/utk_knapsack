# frozen_string_literal: true

mpeg4 = Hydra::Derivatives::Processors::Video::Processor.config.mpeg4
mpeg4.codec += ' -preset veryfast' unless mpeg4.codec.include?('-preset')
