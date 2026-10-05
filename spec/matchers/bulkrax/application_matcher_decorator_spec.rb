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

    it 'keeps the scheme lowercase so UriLabelResolver can resolve it' do
      result = matcher.parse_subject('http://id.loc.gov/authorities/subjects/sh85101348')
      expect(result).to start_with('http://')
    end

    it 'keeps the https scheme lowercase so UriLabelResolver can resolve it' do
      result = matcher.parse_subject('https://id.loc.gov/authorities/subjects/sh85101348')
      expect(result).to start_with('https://')
    end

    it 'normalizes a capitalized Http scheme from the CSV' do
      result = matcher.parse_subject('Http://id.loc.gov/authorities/subjects/sh85101348')
      expect(result).to start_with('http://')
    end

    it 'normalizes a capitalized Https scheme from the CSV' do
      result = matcher.parse_subject('Https://id.loc.gov/authorities/subjects/sh85101348')
      expect(result).to start_with('https://')
    end

    it 'downcases only the scheme of an all-caps URI, preserving the path' do
      result = matcher.parse_subject('HTTP://ID.LOC.GOV/AUTHORITIES/SUBJECTS/SH85101348')
      expect(result).to start_with('http://')
      expect(result).to eq('http://ID.LOC.GOV/AUTHORITIES/SUBJECTS/SH85101348')
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
    it 'preserves URI scheme through the full matcher pipeline so UriLabelResolver can resolve it' do
      result = matcher.result(nil, 'http://id.loc.gov/authorities/subjects/sh85101348')
      expect(result).to start_with('http://')
    end

    it 'normalizes a capitalized URI scheme through the full matcher pipeline' do
      result = matcher.result(nil, 'Http://id.loc.gov/authorities/subjects/sh85101348')
      expect(result).to start_with('http://')
    end
  end
end
