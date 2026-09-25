# frozen_string_literal: true

module Migration
  module Profile
    DEFINITION = YAML.safe_load_file(File.join(ROOT, 'config/metadata_profiles/m3_profile.yaml'))
    MODELS = { 'FileSet' => 'Hyrax::FileSet', 'Collection' => 'DigitalCollection' }.freeze

    ROLE_FOR_COLUMN = %w[creator contributor].each_with_object({}) do |compound, acc|
      YAML.safe_load_file(File.join(ROOT, "config/authorities/#{compound}_roles.yml")).fetch('terms').each do |term|
        column = term['id'].downcase.gsub(/[^a-z0-9]+/, '_')
        acc[column] = acc["utk_#{column}"] = [compound, term['id']]
      end
    end.freeze

    REQUIRED = DEFINITION['properties'].each_with_object(Hash.new { |h, k| h[k] = [] }) do |(name, config), acc|
      next unless config['cardinality'].is_a?(Hash) && config['cardinality']['minimum'].to_i >= 1

      available = config['available_on']
      Array(available.is_a?(Hash) ? available['class'] : available).each { |model| acc[model] << name }
    end

    class << self
      def missing_required(row)
        model = MODELS.fetch(row['model'].to_s, row['model'].to_s)
        REQUIRED[model].select { |property| row[property].to_s.strip.empty? }
                       .map { |property| "#{row['source_identifier']} (#{model}) missing #{property}" }
      end

      def unknown_column?(header)
        header.start_with?('utk_') && !DEFINITION['properties'].key?(header) &&
          !DEFINITION['properties'].key?(header.delete_prefix('utk_'))
      end
    end
  end
end
