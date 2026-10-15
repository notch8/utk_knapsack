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
end
