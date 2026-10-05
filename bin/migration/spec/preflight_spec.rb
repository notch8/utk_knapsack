# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe Migration::Preflight do
  let(:vocabularies) do
    { 'license' => { files: ['licenses.yml'], terms: { 'https://creativecommons.org/licenses/by/4.0/' => 'Attribution 4.0' } },
      'resource_type' => { files: ['resource_types.yml'],
                           terms: { 'http://id.loc.gov/vocabulary/resourceTypes/img' => 'Still image' } } }
  end

  before { stub_const('Migration::Profile::VOCABULARIES', vocabularies) }

  def stops(*rows)
    rows = rows.each_with_index.map { |row, i| { 'source_identifier' => "w:#{i + 1}", 'id' => "id-#{i + 1}" }.merge(row) }
    described_class.new(rows, rows.flat_map(&:keys).uniq).stops
  end

  it 'stops on a row legacy Solr did not match' do
    expect(stops({ 'id' => nil })).to eq ['unmatched source_identifiers: 1 ["w:1"]']
  end

  it 'passes a value the vocabulary holds' do
    expect(stops({ 'license' => 'https://creativecommons.org/licenses/by/4.0/' })).to be_empty
  end

  it 'stops on a value the vocabulary does not hold, naming the property, its file and the rows' do
    expect(stops({ 'license' => 'http://creativecommons.org/licenses/by/4.0/' }, {})).to eq [
      'OFF VOCABULARY: 1 value not in their vocabulary; correct the sheet or add the term',
      '  license (licenses.yml)',
      '    http://creativecommons.org/licenses/by/4.0/: 1 row (w:1), ' \
      'did you mean https://creativecommons.org/licenses/by/4.0/?'
    ]
  end

  it 'flags a label stored where the id belongs, suggesting its id' do
    expect(stops({ 'resource_type' => 'still image' }).last)
      .to eq '    still image: 1 row (w:1), did you mean http://id.loc.gov/vocabulary/resourceTypes/img?'
  end

  it 'suggests an id differing only by trailing slash' do
    expect(stops({ 'license' => 'https://creativecommons.org/licenses/by/4.0' }).last)
      .to end_with 'did you mean https://creativecommons.org/licenses/by/4.0/?'
  end

  it 'suggests nothing for a different version of a term, since that is a different term' do
    expect(stops({ 'license' => 'http://creativecommons.org/licenses/by/3.0/' }).last)
      .to eq '    http://creativecommons.org/licenses/by/3.0/: 1 row (w:1)'
  end

  it 'checks each value of a multi-valued cell' do
    cell = 'http://id.loc.gov/vocabulary/resourceTypes/img | http://id.loc.gov/vocabulary/resourceTypes/txt'
    expect(stops({ 'resource_type' => cell }).last).to eq '    http://id.loc.gov/vocabulary/resourceTypes/txt: 1 row (w:1)'
  end

  it 'groups repeats of one value and samples the rows' do
    rows = Array.new(4) { { 'license' => 'Attribution' } }
    expect(stops(*rows).last).to eq '    Attribution: 4 rows (w:1, w:2, w:3, …)'
  end

  it 'leaves a property with no local vocabulary alone' do
    expect(stops({ 'subject' => 'http://id.loc.gov/authorities/subjects/sh85147554' })).to be_empty
  end
end

RSpec.describe Migration::Profile do
  it 'reads only properties whose every source has a local yml' do
    expect(described_class::VOCABULARIES.keys).to include('resource_type', 'rights_statement')
    expect(described_class::VOCABULARIES.keys).not_to include('title', 'subject', 'spatial', 'language')
  end

  it 'skips a property citing a remote authority beside a local one' do
    expect(described_class.vocabulary_for('controlled_values' => { 'sources' => %w[rights_statements lcsh] })).to be_nil
  end
end
