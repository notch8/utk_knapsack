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

    AUTHORITY_DIRS = [File.join(ROOT, 'config/authorities'), File.join(ROOT, 'hyrax-webapp/config/authorities')].freeze

    class << self
      def missing_required(row)
        model = MODELS.fetch(row['model'].to_s, row['model'].to_s)
        REQUIRED[model].select { |property| row[property].to_s.strip.empty? }
                       .map { |property| "#{row['source_identifier']} (#{model}) missing #{property}" }
      end

      def vocabulary_for(config)
        sources = Array(config.dig('controlled_values', 'sources')) - ['null']
        files = sources.map { |source| AUTHORITY_DIRS.map { |dir| File.join(dir, "#{source}.yml") }.find { |f| File.exist?(f) } }
        return if files.empty? || files.include?(nil)

        terms = files.flat_map { |file| YAML.safe_load_file(file).fetch('terms') }.to_h { |term| [term['id'].to_s, term['term'].to_s] }
        { files: files.map { |file| File.basename(file) }, terms: }
      end

      def suggestion(vocabulary, value)
        vocabulary[:terms].find { |_, label| label.casecmp?(value) }&.first ||
          vocabulary[:terms].keys.find { |id| bare(id) == bare(value) }
      end

      def bare(uri)
        uri.sub(%r{\Ahttps?://}i, '').chomp('/')
      end

      def off_vocabulary(rows)
        VOCABULARIES.each_with_object({}) do |(property, vocabulary), acc|
          rows.each do |row|
            row[property].to_s.split('|').map(&:strip).reject(&:empty?).each do |value|
              next if vocabulary[:terms].key?(value)

              ((acc[property] ||= {})[value] ||= []) << row['source_identifier']
            end
          end
        end
      end

      def unknown_column?(header)
        header.start_with?('utk_') && !DEFINITION['properties'].key?(header) &&
          !DEFINITION['properties'].key?(header.delete_prefix('utk_'))
      end
    end

    VOCABULARIES = DEFINITION['properties'].filter_map { |name, config| (vocabulary = vocabulary_for(config)) && [name, vocabulary] }
                                           .to_h.freeze
  end
end
