# frozen_string_literal: true

require_relative 'spec_helper'
require 'aws-sdk-s3'

RSpec.describe Migration::Derivatives::Stage do
  subject(:stage) { described_class.new(Migration::Target.for(nil), report, dry_run: true) }

  let(:report) { instance_double(Migration::Report, item: nil, failures: nil) }
  let(:intermediate) { 'http://pcdm.org/use#PreservationFile | http://pcdm.org/use#IntermediateFile' }
  let(:rows) do
    [
      { 'source_identifier' => 'memoir', 'model' => 'Pdf' },
      { 'source_identifier' => 'guide', 'model' => 'Book' },
      { 'source_identifier' => 'pdf_with', 'id' => 'aa-with', 'model' => 'FileSet', 'parents' => 'memoir' },
      { 'source_identifier' => 'pdf_without', 'id' => 'bb-without', 'model' => 'FileSet', 'parents' => 'memoir' },
      { 'source_identifier' => 'page_without', 'id' => 'cc-without', 'model' => 'FileSet', 'parents' => 'guide',
        'rdf_type' => intermediate },
      { 'source_identifier' => 'ocr_without', 'id' => 'dd-without', 'model' => 'FileSet', 'parents' => 'guide',
        'rdf_type' => 'http://pcdm.org/use#OriginalFile' }
    ]
  end
  let(:ids) { rows.filter_map { |row| row['id'] } }
  let(:listing) { "131708\t#{Migration.pairtree('aa-with')}-thumbnail.jpeg\n" }
  let(:legacy) { double('legacy', run: [listing, '', instance_double(Process::Status, success?: true)]) }

  around do |example|
    Aws.config.update(stub_responses: true)
    example.run
    Aws.config.delete(:stub_responses)
  end

  it 'counts every file set legacy has no derivatives for' do
    expect { stage.call(ids, legacy) }.to output(/3 file sets with no derivatives/).to_stderr
  end

  it 'names only those legacy should have made derivatives for' do
    expect { stage.call(ids, legacy) }.to output.to_stderr
    expect(stage.missing(rows).map { |row| row['source_identifier'] }).to eq(%w[pdf_without page_without])
  end
end
