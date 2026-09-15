# frozen_string_literal: true

class UriLabelResolver
  LABEL_PREDICATES = {
    'sws.geonames.org' => RDF::URI('http://www.geonames.org/ontology#name'),
    'creativecommons.org' => RDF::URI('http://purl.org/dc/terms/title')
  }.freeze

  URL_REWRITES = {
    'www.wikidata.org' => ->(uri) { uri.sub('/wiki/', '/entity/').chomp('/') + '.nt' },
    'homosaurus.org' => ->(uri) { uri.chomp('/') + '.nt' }
  }.freeze

  LOCAL_AUTHORITIES = {
    'rightsstatements.org' => 'rights_statements',
    'creativecommons.org' => 'licenses'
  }.freeze

  class << self
    def label_for(uri)
      return uri unless uri.to_s.start_with?('http')

      cached = UriCache.find_by(uri:)
      return cached.value if cached

      local_label = resolve_local(uri)
      if local_label
        cache_label(uri, local_label)
        return local_label
      end

      resolve_remote(uri)
    end

    def resolve_remote(uri)
      host = URI(uri).host
      fetch_uri = URL_REWRITES[host]&.call(uri) || uri

      resource = ActiveTriples::Resource.new(RDF::URI(fetch_uri))
      resource.fetch(headers: { 'Accept' => 'application/n-triples, application/rdf+xml;q=0.8, text/turtle;q=0.6' })

      label = extract_label(resource, host)
      return "#{uri} (No label found)" if label.blank?

      cache_label(uri, label)
      label
    rescue StandardError => e
      Rails.logger.error("Failed to load RDF data: #{e.message}")
      "#{uri} (Failed to load URI)"
    end

    private

    def resolve_local(uri)
      host = URI(uri).host
      authority_name = LOCAL_AUTHORITIES[host]
      return unless authority_name

      authority = Qa::Authorities::Local.subauthority_for(authority_name)
      result = authority.find(uri)
      term = result.is_a?(Hash) ? result[:term] || result['term'] : nil
      term.presence
    rescue StandardError
      nil
    end

    def extract_label(resource, host)
      predicate = LABEL_PREDICATES[host]

      if predicate
        objects = resource.graph.query([nil, predicate, nil]).objects
        pick_english(objects) || objects.first&.to_s
      else
        resource.rdf_label.first&.to_s
      end
    end

    def pick_english(objects)
      objects.detect { |o| o.respond_to?(:language) && o.language == :en }&.to_s
    end

    def cache_label(uri, label)
      UriCache.create!(uri:, value: label)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      nil
    end
  end
end
