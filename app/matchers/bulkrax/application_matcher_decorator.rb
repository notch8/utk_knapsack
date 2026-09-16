# frozen_string_literal: true

module Bulkrax
  # OVERRIDE Bulkrax 9.5.1: parse_subject lowercases the entire value then
  # capitalises the first character ("Sentence case"). That mangles URIs:
  # "http://id.loc.gov/…" becomes "Http://id.loc.gov/…", breaking every
  # downstream check that pattern-matches on the scheme.
  #
  # Return URIs verbatim; apply the original sentence-casing only to plain
  # text subjects.
  module ApplicationMatcherDecorator
    def parse_subject(src)
      return if src.blank?
      return src.strip if src.strip.match?(%r{\Ahttps?://}i)

      super
    end
  end
end

Bulkrax::ApplicationMatcher.prepend(Bulkrax::ApplicationMatcherDecorator)
