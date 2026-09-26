# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe Bulkrax::UtkMigrationObjectKey do
  it 'derives the same key the migration factory spec pins' do
    expect(described_class.for(file_set_id: 'cccccccc-4444-5555-6666-dddddddddddd', sha1: 'c19ecaa728169901792d5595f3a11e02cc16e3a0'))
      .to eq 'cccccccc-4444-5555-6666-dddddddddddd/a24a03d2-20e9-534a-9619-7420574d878e'
  end
end
