# frozen_string_literal: true

require_relative 'spec_helper'
require 'tmpdir'

RSpec.describe Migration::Pod do
  subject(:pod) do
    Class.new(described_class) do
      private

      def prefix
        ['env']
      end
    end.new('ctx/ns/deploy')
  end

  before do
    stub_const("#{described_class}::TIMEOUT", 1)
    allow(pod).to receive(:warn)
  end

  def capture(command, stdin = '')
    pod.send(:capture, 'lookup', command, stdin)
  end

  it 'returns output, errors and status of a call that finishes' do
    out, err, status = capture('cat; echo oops >&2', 'hello')

    expect([out, err, status.success?]).to eq(['hello', "oops\n", true])
  end

  it 'retries a call that runs past the timeout' do
    Dir.mktmpdir do |dir|
      out, = capture("[ -f #{dir}/seen ] && echo done || { touch #{dir}/seen; exec sleep 5; }")

      expect(out).to eq("done\n")
    end
  end

  it 'stops after every attempt runs past the timeout' do
    expect { capture('exec sleep 5') }.to raise_error(described_class::Hung, /lookup .* ran past 1s, 2 times/)
  end

  it 'times out a call that never reads its input' do
    expect { capture('exec sleep 5', 'x' * 1_000_000) }.to raise_error(described_class::Hung)
  end

  describe 'with slots' do
    subject(:pod) do
      Class.new(described_class) do
        private

        def prefix
          ['env']
        end
      end.new('ctx/ns/deploy', slots: 1)
    end

    let(:slots) { Dir.mktmpdir }

    before { stub_const("#{described_class}::SLOTS", slots) }
    after { FileUtils.rm_rf(slots) }

    it 'waits for a slot another process holds' do
      File.open(File.join(described_class::SLOTS, '0'), File::RDWR | File::CREAT) do |held|
        held.flock(File::LOCK_EX)
        released = false
        allow(pod).to receive(:sleep) { released = held.flock(File::LOCK_UN) }

        pod.run('lookup', 'x', stdin: -> { released ? '' : raise('read before the slot was free') })

        expect(pod).to have_received(:warn).with(/all 1 in use/)
      end
    end

    it 'runs at once when a slot is free' do
      allow(pod).to receive(:sleep)

      pod.run('lookup', 'x')

      expect(pod).not_to have_received(:sleep)
    end
  end
end
