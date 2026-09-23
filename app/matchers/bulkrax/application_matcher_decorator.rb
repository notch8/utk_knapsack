# frozen_string_literal: true

module Bulkrax
  # OVERRIDE Bulkrax 9.5.1: parse_subject lowercases the entire value then
  # capitalises the first character ("Sentence case"). That mangles URIs:
  # "http://id.loc.gov/…" becomes "Http://id.loc.gov/…", breaking every
  # downstream check that pattern-matches on the scheme.
  #
  # Normalize the URI scheme to lowercase, preserving the rest of the URI;
  # apply the original sentence-casing only to plain text subjects.
  module ApplicationMatcherDecorator
    def parse_subject(src)
      return if src.blank?

      stripped = src.strip
      return stripped.sub(%r{\Ahttps?}i, &:downcase) if stripped.match?(%r{\Ahttps?://}i)

      super
    end
  end
end

Bulkrax::ApplicationMatcher.prepend(Bulkrax::ApplicationMatcherDecorator)
