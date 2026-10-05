# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::IntermediateFile do
  describe '.match?' do
    it 'matches the PCDM use URI' do
      expect(described_class.match?(['http://pcdm.org/use#IntermediateFile'])).to be true
    end

    it 'matches among several types' do
      expect(described_class.match?(['http://pcdm.org/use#PreservationFile', 'http://pcdm.org/use#IntermediateFile'])).to be true
    end

    it 'ignores scheme and case' do
      expect(described_class.match?(['https://pcdm.org/use#intermediatefile'])).to be true
    end

    it 'matches a bare term' do
      expect(described_class.match?('IntermediateFile')).to be true
    end

    it 'rejects other PCDM uses' do
      expect(described_class.match?(['http://pcdm.org/use#PreservationFile', 'http://pcdm.org/use#ServiceFile'])).to be false
    end

    it 'rejects a term that only starts with the fragment' do
      expect(described_class.match?(['http://pcdm.org/use#IntermediateFileSet'])).to be false
    end

    it 'rejects nil and empty' do
      expect(described_class.match?(nil)).to be false
      expect(described_class.match?([])).to be false
    end
  end
end
