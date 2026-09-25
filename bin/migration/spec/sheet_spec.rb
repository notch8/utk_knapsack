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

  it 'keeps a compound object whole as one of the first works, and drops the collection row' do
    expect(sheet.first_works(1).rows.map { |r| r['source_identifier'] }).to eq %w[cmp:1 cmp:1_p1 cmp:1_p1_OBJ]
  end

  it 'survives a row that names itself as its parent' do
    looped = described_class.new(%w[source_identifier model parents], [{ 'source_identifier' => 'a', 'model' => 'Image', 'parents' => 'a' }])
    expect(looped.root_of('a')).to eq 'a'
  end
end
