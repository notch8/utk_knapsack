# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class UriLabelResolver
  SKOS_PREF_LABEL = RDF::URI('http://www.w3.org/2004/02/skos/core#prefLabel')
  DELETION_NOTE = RDF::URI('http://www.loc.gov/mads/rdf/v1#deletionNote')
  OWL_SAME_AS = RDF::URI('http://www.w3.org/2002/07/owl#sameAs')

  LABEL_PREDICATES = {
    'sws.geonames.org' => RDF::URI('http://www.geonames.org/ontology#name'),
    'creativecommons.org' => RDF::URI('http://purl.org/dc/terms/title')
  }.freeze

  URL_REWRITES = {
    'id.loc.gov' => ->(uri) { uri.sub(/\.html\z/, '') },
    'vocab.getty.edu' => ->(uri) { uri.sub('/page/', '/') },
    'www.wikidata.org' => ->(uri) { uri.sub('/wiki/', '/entity/').chomp('/') + '.nt' },
    'sws.geonames.org' => ->(uri) { uri.chomp('/') + '/about.rdf' },
    'creativecommons.org' => ->(uri) { uri.chomp('/') + '/rdf' }
  }.freeze

  SUBJECT_REWRITES = {
    'id.loc.gov' => ->(uri) { uri.sub(/\Ahttps?:/i, 'http:').sub(/\.html\z/, '') },
    'vocab.getty.edu' => ->(uri) { uri.sub(/\Ahttps?:/i, 'http:').sub('/page/', '/') },
    'www.wikidata.org' => ->(uri) { uri.sub(/\Ahttps?:/i, 'http:').sub('/wiki/', '/entity/').chomp('/') },
    'sws.geonames.org' => ->(uri) { uri.sub(/\Ahttps?:/i, 'https:').chomp('/') + '/' }
  }.freeze

  LOCAL_AUTHORITIES = {
    'rightsstatements.org' => 'rights_statements',
    'creativecommons.org' => 'licenses'
  }.freeze

  class << self
    def label_for(uri)
      return uri unless uri.to_s.match?(/\Ahttps?:/i)

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
      subject_uri = SUBJECT_REWRITES[host]&.call(uri) || fetch_uri

      resource = ActiveTriples::Resource.new(RDF::URI(fetch_uri))
      resource.fetch(headers: { 'Accept' => 'application/n-triples, application/rdf+xml;q=0.8, text/turtle;q=0.6' })

      label = extract_label(resource, host, subject_uri, uri)
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

    def extract_label(resource, host, subject_uri, original_uri)
      subject = RDF::URI(subject_uri)
      graph = resource.graph

      deletion = deletion_note_for(graph, subject)
      return "#{original_uri} (Failed to load URI) - #{deletion}" if deletion

      predicate = LABEL_PREDICATES[host]
      return predicate_label(graph, predicate) if predicate

      skos_label_for(graph, subject) ||
        follow_same_as(graph, subject) ||
        resource.rdf_label.reject { |l| l.to_s.match?(/\Ahttps?:/i) }.first&.to_s
    end

    def predicate_label(graph, predicate)
      objects = graph.query([nil, predicate, nil]).objects
      pick_english(objects) || objects.first&.to_s
    end

    def skos_label_for(graph, subject)
      labels = graph.query([subject, SKOS_PREF_LABEL, nil]).objects
      result = pick_english(labels)
      return result if result

      labels.first&.to_s.presence
    end

    def follow_same_as(graph, original_subject)
      targets = graph.query([original_subject, OWL_SAME_AS, nil]).objects
      targets.each do |target|
        label = skos_label_for(graph, target)
        return label if label
      end

      graph.query([nil, OWL_SAME_AS, nil]).subjects.uniq.each do |alt_subject|
        next if alt_subject == original_subject
        label = skos_label_for(graph, alt_subject)
        return label if label
      end

      nil
    end

    def deletion_note_for(graph, subject)
      graph.query([subject, DELETION_NOTE, nil]).objects.first&.to_s
    end

    def pick_english(objects)
      english = objects.detect do |o|
        next false unless o.respond_to?(:language) && o.language.present?
        o.language.to_s.match?(/\Aen([-_]|\z)/i)
      end
      english&.to_s
    end

    def cache_label(uri, label)
      UriCache.create!(uri:, value: label)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      nil
    end
  end
end
# rubocop:enable Metrics/ClassLength
