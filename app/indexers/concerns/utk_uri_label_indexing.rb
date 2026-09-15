# frozen_string_literal: true

module UtkUriLabelIndexing
  class << self
    def uri_properties
      current_id = Hyrax::FlexibleSchema.order(created_at: :desc).pick(:id)
      return [] unless current_id

      cache_key = "#{Apartment::Tenant.current}:#{current_id}"
      return @cached_properties if @cached_key == cache_key

      schema = Hyrax::FlexibleSchema.find(current_id)
      @cached_properties = extract_controlled_properties(schema.profile).freeze
      @cached_key = cache_key
      @cached_properties
    end

    def reset_cache!
      @cached_key = nil
      @cached_properties = nil
    end

    private

    def extract_controlled_properties(profile)
      profile.fetch('properties', {}).each_with_object([]) do |(name, config), result|
        sources = Array(config.dig('controlled_values', 'sources'))
                  .reject { |s| s.nil? || s == 'null' }
        next if sources.empty?

        result << name.to_sym
      end
    end
  end

  def to_solr(*args, **kwargs, &block)
    super(*args, **kwargs, &block).tap do |solr_doc|
      UtkUriLabelIndexing.uri_properties.each do |property|
        values = Array(resource.try(property)).map(&:to_s).select(&:present?)
        uris = values.select { |v| v.start_with?('http') }
        next if uris.empty?

        labels = uris.map { |uri| UriLabelResolver.label_for(uri) }
        solr_doc["#{property}_label_tesim"] = labels if labels.any?
      end
    end
  end
end
