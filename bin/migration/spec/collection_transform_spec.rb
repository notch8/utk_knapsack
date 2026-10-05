# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe Migration::CollectionTransform do
  let(:row) do
    { 'source_identifier' => 'collections:x', 'model' => 'DigitalCollection', 'title' => 'X',
      'visibility' => 'open', 'provider' => 'University of Tennessee, Knoxville. Libraries',
      'rights_statement' => 'http://rightsstatements.org/vocab/CNE/1.0/',
      'photographer' => 'http://id.loc.gov/authorities/names/n1', 'utk_creator' => 'Bishop, Evelyn | Sturley, Ruth',
      'redirect_path' => 'x', 'redirect_is_display_url' => 'TRUE' }
  end
  let(:result) { described_class.new(Migration::Sheet.new(row.keys, [row])).call }
  let(:out) { result.rows.first }

  it 'carries the source identifier as the primary identifier' do
    expect(out['primary_identifier']).to eq 'collections:x'
  end

  it 'keeps rights_statement, the attribute collections import it to' do
    expect(out['rights_statement']).to eq 'http://rightsstatements.org/vocab/CNE/1.0/'
  end

  it 'collapses role columns into the creator compound' do
    expect(out.values_at(*%w[creator_name_1 creator_role_1 creator_name_2 creator_role_2 creator_name_3]))
      .to eq ['http://id.loc.gov/authorities/names/n1', 'Photographer', 'Bishop, Evelyn', 'Creator', 'Sturley, Ruth']
    expect(out.keys).not_to include('photographer', 'utk_creator')
  end

  it 'keeps parents for nested collections' do
    nested = row.merge('parents' => 'collections:p')
    out = described_class.new(Migration::Sheet.new(nested.keys, [nested])).call.rows.first
    expect(out['parents']).to eq 'collections:p'
  end

  it 'passes redirects through and adds no id column' do
    expect(out.values_at('redirect_path', 'redirect_is_display_url')).to eq %w[x TRUE]
    expect(out).not_to have_key('id')
  end

  it 'does not stop for rows that were never looked up' do
    expect(result.stops).to be_empty
  end
end
