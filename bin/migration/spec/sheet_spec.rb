# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe Migration::Sheet do
  let(:rows) do
    [%w[collections:x Collection], %w[cmp:1 CompoundObject collections:x], %w[cmp:1_p1 Image cmp:1],
     %w[cmp:1_p1_OBJ FileSet cmp:1_p1], %w[solo:1 Image collections:x], %w[solo:1_OBJ FileSet solo:1]]
      .map { |id, model, parents| { 'source_identifier' => id, 'model' => model, 'parents' => parents } }
  end
  let(:sheet) { described_class.new(%w[source_identifier model parents], rows) }

  it 'climbs from a file set to its top-level work, never into the collection' do
    expect(sheet.root_of('cmp:1_p1_OBJ')).to eq 'cmp:1'
  end

  it 'lists a file set\'s works from nearest to top-level' do
    expect(sheet.ancestors('cmp:1_p1_OBJ')).to eq %w[cmp:1_p1 cmp:1]
  end

  it 'keeps a compound object whole as one of the first works, and drops the collection row' do
    expect(sheet.first_works(1).rows.map { |r| r['source_identifier'] }).to eq %w[cmp:1 cmp:1_p1 cmp:1_p1_OBJ]
  end

  it 'keeps each work\'s first members with everything under them, and every top-level row' do
    pages = [%w[cmp:1_p2 Image cmp:1], %w[cmp:1_p2_OBJ FileSet cmp:1_p2], %w[solo:1_MODS FileSet solo:1]]
            .map { |id, model, parents| { 'source_identifier' => id, 'model' => model, 'parents' => parents } }
    paged = rows + pages
    sliced = described_class.new(%w[source_identifier model parents], paged).first_members(1)
    expect(sliced.rows.map { |r| r['source_identifier'] })
      .to eq %w[collections:x cmp:1 cmp:1_p1 cmp:1_p1_OBJ solo:1 solo:1_OBJ]
  end

  it 'keeps a work\'s members in page order, unsequenced last' do
    book = [%w[bk:1 Book], %w[bk:1_MODS FileSet bk:1], %w[bk:1_p2 FileSet bk:1 2], %w[bk:1_p1 FileSet bk:1 1]]
           .map { |id, model, parents, sequence| { 'source_identifier' => id, 'model' => model, 'parents' => parents, 'sequence' => sequence } }
    sliced = described_class.new(%w[source_identifier model parents sequence], book).first_members(1)
    expect(sliced.rows.map { |r| r['source_identifier'] }).to eq %w[bk:1 bk:1_p1]
  end

  it 'survives a row that names itself as its parent' do
    looped = described_class.new(%w[source_identifier model parents], [{ 'source_identifier' => 'a', 'model' => 'Image', 'parents' => 'a' }])
    expect(looped.root_of('a')).to eq 'a'
  end
end
