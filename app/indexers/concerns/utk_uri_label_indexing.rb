# frozen_string_literal: true

module UtkUriLabelIndexing
  class << self
    def uri_properties
      current_id, updated_at = Hyrax::FlexibleSchema.order(created_at: :desc).pick(:id, :updated_at)
      return [] unless current_id

      cache_key = "#{Apartment::Tenant.current}:#{current_id}:#{updated_at.to_i}"
      cached = @uri_properties_cache
      return cached.last if cached&.first == cache_key

      schema = Hyrax::FlexibleSchema.find(current_id)
      properties = extract_controlled_properties(schema.profile).freeze
      @uri_properties_cache = [cache_key, properties].freeze
      properties
    end

    def reset_cache!
      @uri_properties_cache = nil
    end

    private

    def extract_controlled_properties(profile)
      profile.fetch('properties', {}).each_with_object([]) do |(name, config), result|
        sources = Array(config.dig('controlled_values', 'sources'))
                  .reject { |s| s.nil? || s == 'null' }
        next if sources.empty?
        # A local vocabulary already holds the label, and Hyrax indexes it beside the id.
        # Resolving one here would fetch a URI we ship the term for, which is a network
        # call per value during a reindex and caches a label we already have.
        next if sources.all? { |source| locally_resolvable?(source) }

        result << name.to_sym
      end
    end

    def locally_resolvable?(source)
      Hyrax.config.controlled_vocabulary_label_service.resolvable?(source)
    rescue StandardError => e
      Hyrax.logger.debug { "Unable to classify controlled vocabulary #{source}: #{e.message}" }
      false
    end
  end

  def to_solr(*args, **kwargs, &block)
    super(*args, **kwargs, &block).tap do |solr_doc|
      UtkUriLabelIndexing.uri_properties.each do |property|
        values = Array(resource.try(property)).map(&:to_s).select(&:present?)
        next unless values.any? { |v| v.match?(%r{\Ahttps?://}i) }

        labels = values.map { |v| v.match?(%r{\Ahttps?://}i) ? UriLabelResolver.label_for(v) : v }
        write_labels(solr_doc, property, labels)
      end

      resolve_compound_uris(solr_doc)
    end
  end

  private

  # Beside the stored URI rather than over it, matching how Hyrax indexes a local
  # vocabulary: the id stays as the link target and what OAI harvests, and the catalog
  # and show page read the label companion. Every index key the property already has
  # gets one, so a facet resolves as well as a row.
  def write_labels(solr_doc, property, labels)
    keys = solr_doc.keys.select { |key| key.to_s.match?(/\A#{Regexp.escape(property.to_s)}_[^_]+\z/) }
    keys.each do |key|
      label_key = Hyrax::ControlledVocabularyFieldValues.label_key(key.to_s)
      solr_doc[label_key] = labels unless label_key == key.to_s
    end
  end

  def resolve_compound_uris(solr_doc)
    solr_doc.keys.grep(/_json_ss\z/).each do |json_key|
      rows = JSON.parse(solr_doc[json_key])
      resolve_uris_in_rows!(rows)

      solr_doc[json_key] = rows.to_json
      sync_searchable_fields(solr_doc, json_key.sub(/_json_ss\z/, ''), rows)
    end
  end

  def resolve_uris_in_rows!(rows)
    rows.each { |row| row.transform_values! { |v| UriLabelResolver.label_for(v) } }
  end

  def sync_searchable_fields(solr_doc, compound, rows)
    rows.flat_map(&:keys).uniq.each do |sub_prop|
      values = rows.filter_map { |r| r[sub_prop].presence }
      %w[_tesim _sim _ssim].each do |sfx|
        key = "#{compound}_#{sub_prop}#{sfx}"
        solr_doc[key] = values if solr_doc.key?(key)
      end
    end
  end
end
