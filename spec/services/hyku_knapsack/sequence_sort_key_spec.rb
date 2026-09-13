# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::SequenceSortKey do
  describe '.call' do
    it 'reads the integer out of a single-element array' do
      expect(described_class.call(['3'])).to eq(3)
    end

    it 'takes the lowest value when the property carries several' do
      expect(described_class.call(['7', '3', '10'])).to eq(3)
    end

    it 'compares numerically rather than lexically' do
      expect(described_class.call(['10', '2'])).to eq(2)
    end

    it 'accepts an integer that was never serialized to a string' do
      expect(described_class.call([4])).to eq(4)
    end

    it 'accepts a bare value outside an array' do
      expect(described_class.call('5')).to eq(5)
    end

    it 'strips leading zeros rather than treating them as significant' do
      expect(described_class.call(['0001'])).to eq(1)
    end

    it 'accepts a negative integer, which the XSD range permits' do
      expect(described_class.call(['-2', '5'])).to eq(-2)
    end

    it 'accepts the leading + that the XSD integer lexical form permits' do
      expect(described_class.call(['+3'])).to eq(3)
    end

    it 'ignores surrounding whitespace' do
      expect(described_class.call([' 6 '])).to eq(6)
    end

    it 'returns nil for a missing value' do
      expect(described_class.call(nil)).to be_nil
    end

    it 'returns nil for an empty array' do
      expect(described_class.call([])).to be_nil
    end

    it 'returns nil for a blank string' do
      expect(described_class.call([''])).to be_nil
    end

    it 'returns nil for the literal "[]" the legacy index carries' do
      expect(described_class.call(['[]'])).to be_nil
    end

    it 'returns nil for a value that is not an integer' do
      expect(described_class.call(['page 3'])).to be_nil
    end

    it 'returns nil for a decimal, which is not an XSD integer' do
      expect(described_class.call(['3.5'])).to be_nil
    end

    it 'keeps the usable value when it sits beside an unusable one' do
      expect(described_class.call(['[]', '8'])).to eq(8)
    end
  end
end
