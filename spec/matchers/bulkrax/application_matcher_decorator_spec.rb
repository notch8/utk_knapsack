# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::ApplicationMatcherDecorator do
  subject(:matcher) { Bulkrax::ApplicationMatcher.new(to: 'subject', parsed: true, split: nil, if: nil, excluded: false, nested_type: nil) }

  describe '#parse_subject' do
    it 'preserves http URIs verbatim' do
      uri = 'http://id.loc.gov/authorities/subjects/sh85101348'
      expect(matcher.parse_subject(uri)).to eq(uri)
    end

    it 'preserves https URIs verbatim' do
      uri = 'https://id.loc.gov/authorities/subjects/sh85101348'
      expect(matcher.parse_subject(uri)).to eq(uri)
    end

    it 'strips whitespace from URIs' do
      expect(matcher.parse_subject('  http://id.loc.gov/authorities/subjects/sh85101348  '))
        .to eq('http://id.loc.gov/authorities/subjects/sh85101348')
    end

    it 'still sentence-cases plain text subjects' do
      expect(matcher.parse_subject('photography')).to eq('Photography')
    end

    it 'still sentence-cases multi-word plain text' do
      expect(matcher.parse_subject('CIVIL WAR')).to eq('Civil war')
    end

    it 'returns nil for blank values' do
      expect(matcher.parse_subject('')).to be_nil
    end
  end

  describe 'integration with #result' do
    it 'does not capitalize URIs when processing through the full matcher pipeline' do
      result = matcher.result(nil, 'http://id.loc.gov/authorities/subjects/sh85101348')
      expect(result).to eq('http://id.loc.gov/authorities/subjects/sh85101348')
    end
  end
end
