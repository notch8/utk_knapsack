# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::DateRangeYears do
  describe '.call' do
    it 'reads a bare year' do
      expect(described_class.call('1911')).to eq [1911]
    end

    it 'reads a year and month' do
      expect(described_class.call('1962-11')).to eq [1962]
    end

    it 'reads a full date' do
      expect(described_class.call('1954-01-14')).to eq [1954]
    end

    it 'reads every value it is given, sorted and deduplicated' do
      expect(described_class.call('1968-10-09', '1911', '1911')).to eq [1911, 1968]
    end

    it 'flattens nested values, so an indexer can pass array-valued properties straight through' do
      expect(described_class.call([['1911'], ['1962-11']])).to eq [1911, 1962]
    end

    it 'drops the "[]" sentinel Hyrax writes for an empty attribute' do
      expect(described_class.call('[]')).to be_empty
    end

    it 'drops nil' do
      expect(described_class.call(nil)).to be_empty
    end

    it 'drops a blank string' do
      expect(described_class.call('   ')).to be_empty
    end

    it 'drops free text carrying no year' do
      expect(described_class.call('n.d.', 'undated')).to be_empty
    end

    it 'reads a three digit year, which UTK uses for ancient and medieval dates' do
      expect(described_class.call('113')).to eq [113]
    end

    it 'drops a two digit year, whose century is unknowable' do
      expect(described_class.call('81')).to be_empty
    end

    it 'drops a two digit month/day/year, which carries no century either' do
      expect(described_class.call('6/19/20', '1/2/00')).to be_empty
    end

    it 'drops a day-month-year abbreviation' do
      expect(described_class.call('1-Aug-68')).to be_empty
    end

    it 'drops EDTF unspecified digits, which UTK does not use' do
      expect(described_class.call('19XX', '196X')).to be_empty
    end

    it 'keeps the parsable values when only some of them parse' do
      expect(described_class.call('[]', '1905', nil)).to eq [1905]
    end

    it 'reads a Date, which stringifies to a full date' do
      expect(described_class.call(Date.new(1954, 1, 14))).to eq [1954]
    end
  end

  describe '.call, with EDTF intervals' do
    it 'contributes every year an interval spans' do
      expect(described_class.call('1940/1943')).to eq [1940, 1941, 1942, 1943]
    end

    it 'ignores the approximation qualifier' do
      expect(described_class.call('1940~/1942')).to eq [1940, 1941, 1942]
    end

    it 'takes the one readable endpoint of an open interval' do
      expect(described_class.call('1940/..')).to eq [1940]
    end

    it 'takes the one readable endpoint when the interval opens at the start' do
      expect(described_class.call('../1940')).to eq [1940]
    end

    it 'orders the endpoints, so a reversed interval still expands' do
      expect(described_class.call('1943/1940')).to eq [1940, 1941, 1942, 1943]
    end

    it 'collapses an interval whose endpoints are the same year' do
      expect(described_class.call('1940-01/1940-12')).to eq [1940]
    end

    it 'expands a three digit interval, as UTK records Roman dates' do
      expect(described_class.call('312/315')).to eq [312, 313, 314, 315]
    end

    # The values below are the widest real intervals in the legacy index, and
    # every one of them used to lose its year entirely and file the work as
    # undated. `1791/1999` not matching a search for 1900 was the symptom.
    it 'expands a span of several centuries, such as 4th to 8th century' do
      expect(described_class.call('301/800')).to eq (301..800).to_a
    end

    it 'expands the widest genuine span in the legacy index' do
      expect(described_class.call('1093/1800').length).to eq 708
    end

    it 'covers the interior of a wide interval, so a mid-range year matches' do
      expect(described_class.call('1791/1999')).to include 1900
    end

    it 'truncates rather than rejecting an implausibly wide interval' do
      years = described_class.call('0000/9999')

      expect(years.length).to eq described_class::MAX_INTERVAL_SPAN
    end

    it 'still dates a work whose interval is implausibly wide' do
      expect(described_class.call('0000/9999')).not_to be_empty
    end
  end
end
