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

  it 'with skip_missing drops only the file set and keeps its work' do
    result = described_class.new(sheet, lookup, skip_missing: true).call
    expect(result.rows.map { |r| r['source_identifier'] }).to eq %w[w:1 w:1_OBJ w:2]
    expect(result.flagged).to eq('w:2_OBJ' => { 'model' => 'FileSet', 'parents' => 'w:2', 'reason' => 'no digest in legacy Solr' })
    expect(result.stops).not_to include(a_string_starting_with('NO DIGEST'))
  end

  it 'flags a file set whose original the copy step found missing' do
    result = described_class.new(sheet, lookup.merge('w:2_OBJ' => lookup['w:1_OBJ'].merge('id' => 'fs-2')),
                                 skip_missing: true, excluded: ['fs-2']).call
    expect(result.flagged.keys).to eq ['w:2_OBJ']
    expect(result.flagged['w:2_OBJ']['reason']).to eq 'original missing in besties-fcrepo'
  end

  it 'with skip_missing drops a work legacy lacks with everything under it' do
    result = described_class.new(sheet, lookup.except('w:2'), skip_missing: true).call
    expect(result.rows.map { |r| r['source_identifier'] }).to eq %w[w:1 w:1_OBJ]
    expect(result.flagged.transform_values { |f| f['reason'] })
      .to eq('w:2' => 'not found in legacy Solr', 'w:2_OBJ' => 'no digest in legacy Solr')
  end

  it 'drops only the subtree of a child work legacy lacks' do
    rows = [%w[cmp:1 CompoundObject], %w[cmp:1_p1 Image cmp:1], %w[cmp:1_p1_OBJ FileSet cmp:1_p1],
            %w[cmp:1_p2 Image cmp:1], %w[cmp:1_p2_OBJ FileSet cmp:1_p2]]
           .map { |id, model, parents| { 'source_identifier' => id, 'model' => model, 'parents' => parents } }
    digest = { 'digest_ssim' => ["urn:sha1:#{'a' * 40}"] }
    found = { 'cmp:1' => { 'id' => 'c' }, 'cmp:1_p2' => { 'id' => 'p2' },
              'cmp:1_p1_OBJ' => digest.merge('id' => 'f1'), 'cmp:1_p2_OBJ' => digest.merge('id' => 'f2') }
    result = described_class.new(Migration::Sheet.new(%w[source_identifier model parents], rows), found, skip_missing: true).call
    expect(result.rows.map { |r| r['source_identifier'] }).to eq %w[cmp:1 cmp:1_p2 cmp:1_p2_OBJ]
    expect(result.flagged['cmp:1_p1_OBJ']['reason']).to eq 'under cmp:1_p1, which is left out'
  end
end
