# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'config/initializers/default_bulkrax_mappings.rb' do
  let(:mappings) { Hyku.default_bulkrax_field_mappings[Bulkrax::UtkMigrationCsvParser.to_s] }

  # Without a key of its own the parser gets no mapping at all, and
  # `HasMatchers#field_to` then falls every column back to its own name: no
  # `split` on the pipe-delimited columns, and no parent wiring.
  it 'gives the migration parser its own mappings' do
    expect(mappings).to be_present
  end

  it 'keeps the parent mapping the relationship pass depends on' do
    expect(mappings['parents']).to include(related_parents_field_mapping: true)
  end

  it 'gives the stock CSV parser the same columns' do
    stock = Hyku.default_bulkrax_field_mappings[Bulkrax::CsvParser.to_s]

    expect(stock).to eq mappings
  end
end
# rubocop:enable RSpec/DescribeClass
