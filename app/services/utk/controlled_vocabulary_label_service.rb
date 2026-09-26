# frozen_string_literal: true

module Utk
  # UTK's controlled properties cite remote authorities, which Hyku declines to resolve
  # because resolving one upstream means an HTTP request per value during indexing.
  # `UriLabelResolver` makes that affordable: a URI is fetched once, stored in
  # `UriCache`, and read from there afterwards.
  #
  # Resolution belongs here rather than in an indexer because Hyrax asks this service
  # whether a vocabulary resolves before it writes a label field, and again before the
  # catalog reads one back. A service that answered false for the remote sources would
  # leave the catalog rendering raw URIs for labels the index already holds.
  class ControlledVocabularyLabelService < Hyku::ControlledVocabularyLabelService
    # Any named source. The cache is keyed by URI and knows nothing about which
    # vocabulary a URI came from, so listing the remote authorities here would be a
    # second place to update whenever the profile cites a new one. A source nothing can
    # resolve falls through to the stored id, which is what it would render anyway.
    def resolvable?(source)
      source.to_s.strip.present?
    end

    # One entry per value, in the order given: Hyrax pairs values to labels by index,
    # so a value nothing resolves has to hold its place as the stored id.
    def labels_for(source, values)
      values = Array.wrap(values)
      # Per value, not per call: `super` answers for a local vocabulary and hands back
      # whatever it has no term for, so comparing the lists as a whole would let one
      # value the vocabulary holds short-circuit resolution for all the others.
      values.zip(Array.wrap(super)).map do |value, label|
        label == value ? uri_label(value) : label
      end
    end

    private

    # `label_for` returns the URI itself when it cannot resolve one, and annotates a
    # failure (`<uri> (No label found)`), so anything that still starts with the URI is
    # left as the stored id rather than shown to a reader.
    def uri_label(value)
      return value unless value.to_s.match?(%r{\Ahttps?://}i)

      label = UriLabelResolver.label_for(value)
      label.to_s.start_with?(value.to_s) ? value : label
    rescue StandardError => e
      Hyrax.logger.debug { "Unable to resolve label for #{value}: #{e.message}" }
      value
    end
  end
end
