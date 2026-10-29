# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::WebPlayable do
  def fixture(name)
    HykuKnapsack::Engine.root.join('spec/fixtures/av', name)
  end

  it 'plays H.264 video with AAC audio in an MP4' do
    expect(described_class.match?('video/mp4', fixture('h264.mp4'))).to be true
  end

  it 'does not play an MP4 whose video is not H.264' do
    expect(described_class.match?('video/mp4', fixture('mpeg4.mp4'))).to be false
  end

  it 'does not play 10-bit H.264, which most browsers cannot decode' do
    expect(described_class.match?('video/mp4', fixture('h264_10bit.mp4'))).to be false
  end

  it 'does not play H.264 in a QuickTime container' do
    expect(described_class.match?('video/quicktime', fixture('h264.mp4'))).to be false
  end

  it 'does not play an MP4 ffprobe cannot read' do
    expect(described_class.match?('video/mp4', fixture('missing.mp4'))).to be false
  end

  it 'plays MP3 audio' do
    expect(described_class.match?('audio/mpeg', fixture('mp3.mp3'))).to be true
  end

  it 'plays MP3 audio with embedded cover art' do
    expect(described_class.match?('audio/mpeg', fixture('mp3_cover_art.mp3'))).to be true
  end

  it 'does not play MPEG Layer II audio, which shares the MP3 mime type' do
    expect(described_class.match?('audio/mpeg', fixture('mp2.mp2'))).to be false
  end

  it 'does not play an audio file whose mime type hides a video stream' do
    expect(described_class.match?('audio/mpeg', fixture('h264.mp4'))).to be false
  end

  it 'does not play WAV audio' do
    expect(described_class.match?('audio/x-wav', fixture('missing.wav'))).to be false
  end
end
