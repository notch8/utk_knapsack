# frozen_string_literal: true

require_relative 'spec_helper'
require 'tmpdir'

RSpec.describe Migration::Progress do
  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, 'progress.json') }

  after { FileUtils.rm_rf(dir) }

  let(:target) { Migration::Target.for(nil) }

  def progress(**options)
    described_class.new(path, target, **options).tap { |p| %w[originals stage].each { |step| p.key!(step, "#{step}-work") } }
  end

  it 'remembers finished steps and cursors across runs' do
    first = progress
    first.done!('originals')
    2.times { first.advance!('stage', 50) }

    again = progress
    expect([again.done?('originals'), again.cursor('stage'), again.done?('stage')]).to eq([true, 100, false])
  end

  it 'starts a step over when its key changed, leaving the others' do
    first = progress
    first.done!('originals')
    first.advance!('stage', 50)

    again = described_class.new(path, target)
    again.key!('originals', 'originals-work')
    again.key!('stage', 'other ids')
    expect([again.done?('originals'), again.cursor('stage')]).to eq([true, 0])
  end

  it 'ignores the saved file but writes a fresh one when told not to read, as --recheck does' do
    progress.done!('originals')
    recheck = progress(read: false)
    recheck.done!('stage')

    expect([recheck.done?('originals'), JSON.parse(File.read(path)).keys]).to eq([false, %w[originals stage]])
    expect(JSON.parse(File.read(path))['originals']['done']).to be(false)
  end

  it 'clears the saved file as soon as a run that does not read starts, so a stopped --recheck leaves nothing stale' do
    progress.done!('originals')
    described_class.new(path, target, read: false)

    expect(progress.done?('originals')).to be(false)
  end

  it 'starts a step over when the destination changed' do
    progress.done!('originals')
    elsewhere = described_class.new(path, Migration::Target.for('production'))
    elsewhere.key!('originals', 'originals-work')

    expect(elsewhere.done?('originals')).to be(false)
  end

  it 'skips a finished step and marks a step done only when its block says so' do
    first = progress
    first.run('originals') { false }
    first.run('stage') { true }
    ran = []
    expect { progress.run('stage') { ran << :stage } }.to output(/done in an earlier run/).to_stderr

    expect([first.done?('originals'), ran]).to eq([false, []])
  end

  it 'writes nothing when told not to write, as --dry-run does' do
    progress(write: false).done!('originals')

    expect(File.exist?(path)).to be(false)
  end

  it 'starts fresh from an unreadable file' do
    File.write(path, '{"originals":')

    expect(progress.done?('originals')).to be(false)
  end
end
