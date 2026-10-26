# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe Migration::CsvPreflight do
  before { stub_const('Migration::Profile::VOCABULARIES', {}) }

  def stops(*rows)
    rows = rows.each_with_index.map do |row, i|
      { 'source_identifier' => "w:#{i + 1}_MODS_fileset", 'model' => 'FileSet', 'parents' => 'w:1',
        'primary_identifier' => "w:#{i + 1}", 'title' => 'MODS', 'rdf_type' => 'http://pcdm.org/file-format-types#Markup',
        'remote_files' => "https://example.org/#{i + 1}.xml" }.merge(row)
    end
    described_class.new(rows, rows.flat_map(&:keys).uniq).stops
  end

  it 'passes file set rows with a remote file and no digest' do
    expect(stops({}, {})).to be_empty
  end

  it 'stops on a source_identifier that appears twice' do
    expect(stops({ 'source_identifier' => 'w:1' }, { 'source_identifier' => 'w:1' })).to eq ['DUPLICATE ROWS: 1 ["w:1"]']
  end

  it 'stops on role columns, which only the migration transform converts' do
    stub_const('Migration::Profile::ROLE_FOR_COLUMN', { 'creator' => %w[creator Creator] })
    expect(stops({ 'creator' => 'Smith' })).to eq ['ROLE COLUMNS need <compound>_name_N and <compound>_role_N: creator']
  end

  it 'passes creator_name_N columns' do
    expect(stops({ 'creator_name_1' => 'Smith', 'creator_role_1' => 'Author' })).to be_empty
  end

  it 'stops on an https pcdm rdf_type' do
    expect(stops({ 'rdf_type' => 'https://pcdm.org/use#OriginalFile' }))
      .to eq ['HTTPS RDF_TYPE: 1 rows use https://pcdm.org ["w:1_MODS_fileset"]']
  end

  it 'stops on a file set with no remote file' do
    expect(stops({ 'remote_files' => '' })).to eq ['NO REMOTE FILE: 1 file sets ["w:1_MODS_fileset"]']
  end
end
