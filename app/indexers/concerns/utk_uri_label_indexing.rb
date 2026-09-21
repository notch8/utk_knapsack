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

        result << name.to_sym
      end
    end
  end

  def to_solr(*args, **kwargs, &block)
    super(*args, **kwargs, &block).tap do |solr_doc|
      UtkUriLabelIndexing.uri_properties.each do |property|
        values = Array(resource.try(property)).map(&:to_s).select(&:present?)
        next unless values.any? { |v| v.match?(%r{\Ahttps?://}) }

        solr_doc["#{property}_tesim"] = values.map do |v|
          v.match?(%r{\Ahttps?://}) ? UriLabelResolver.label_for(v) : v
        end
      end
    end
  end
end
