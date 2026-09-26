# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe Migration::Transform do
  let(:sheet) do
    Migration::Sheet.new(%w[source_identifier model parents], [
                           { 'source_identifier' => 'w:1', 'model' => 'Image', 'parents' => 'collections:x' },
                           { 'source_identifier' => 'w:1_OBJ', 'model' => 'FileSet', 'parents' => 'w:1' },
                           { 'source_identifier' => 'w:2', 'model' => 'Image', 'parents' => 'collections:x' },
                           { 'source_identifier' => 'w:2_OBJ', 'model' => 'FileSet', 'parents' => 'w:2' }
                         ])
  end
  let(:lookup) do
    { 'w:1' => { 'id' => 'id-1' }, 'w:1_OBJ' => { 'id' => 'fs-1', 'digest_ssim' => ["urn:sha1:#{'a' * 40}"] },
      'w:2' => { 'id' => 'id-2' }, 'w:2_OBJ' => { 'id' => 'fs-2', 'digest_ssim' => [] } }
  end

  it 'renames Image to StillImage and carries the sha1 without its urn prefix' do
    rows = described_class.new(sheet, lookup).call.rows
    expect(rows.map { |r| r['model'] }.uniq).to eq %w[StillImage FileSet]
    expect(rows[1]['sha1']).to eq 'a' * 40
  end

  it 'stops on a file set with no digest unless told to skip' do
    expect(described_class.new(sheet, lookup).call.stops).to include(a_string_starting_with('NO DIGEST: 1'))
  end

  it 'with skip_missing drops the whole work and flags it with the reason' do
    result = described_class.new(sheet, lookup, skip_missing: true).call
    expect(result.rows.map { |r| r['source_identifier'] }).to eq %w[w:1 w:1_OBJ]
    expect(result.flagged.keys).to eq ['w:2']
    expect(result.flagged['w:2']).to eq [['w:2_OBJ', ['no digest in legacy Solr']]]
  end

  it 'flags a work whose original the copy step found missing' do
    result = described_class.new(sheet, lookup.merge('w:2_OBJ' => lookup['w:1_OBJ'].merge('id' => 'fs-2')),
                                 skip_missing: true, excluded: ['fs-2']).call
    expect(result.flagged['w:2'].first.last).to eq ['original missing in besties-fcrepo']
  end
end
