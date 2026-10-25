# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe Migration::CsvCheck do
  let(:app) do
    Class.new do
      def run(*, **)
        yield "MARKER collections:c\tCollectionResource\n"
        yield "MARKER w:1\tStillImage\n"
        Struct.new(:success?).new(true)
      end
    end.new
  end

  def stops(*parents)
    rows = parents.each_with_index.map do |parent, i|
      { 'source_identifier' => "w:1_#{i}_fileset", 'model' => 'FileSet', 'parents' => parent }
    end
    sheet = Migration::Sheet.new(%w[source_identifier model parents], rows)
    described_class.new(sheet, app, 'dc').send(:target_stops)
  end

  it 'stops on a file set whose parent is a collection on the tenant' do
    expect(stops('collections:c', 'w:1').first(2))
      .to eq ["FILE SETS UNDER A COLLECTION: 1; a file set's parent must be its work", '  w:1_0_fileset -> collections:c']
  end

  it 'passes file sets whose parent is a work' do
    expect(stops('w:1')).to be_empty
  end
end
