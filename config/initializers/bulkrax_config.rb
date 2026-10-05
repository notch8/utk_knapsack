# frozen_string_literal: true

Rails.application.config.to_prepare do
  next unless Hyku.bulkrax_enabled?

  Bulkrax.setup do |config|
    config.parsers -= [
      { name: "OAI - Dublin Core", class_name: "Bulkrax::OaiDcParser", partial: "oai_fields" },
      { name: "OAI - Qualified Dublin Core", class_name: "Bulkrax::OaiQualifiedDcParser", partial: "oai_fields" },
      { name: "XML", class_name: "Bulkrax::XmlParser", partial: "xml_fields" }
    ]

    config.fill_in_blank_source_identifiers = lambda do |obj, index|
      "#{Site.instance.account.name}-#{obj.importerexporter.id}-#{index}"
    end

    config.default_field_mapping = lambda do |field|
      return if field.blank?
      {
        field.to_s =>
        {
          from: [field.to_s],
          split: /\s*[|]\s*/,
          parsed: Bulkrax::ApplicationMatcher.method_defined?("parse_#{field}"),
          if: nil,
          excluded: false
        }
      }
    end

    config.qa_controlled_properties |= ['resource_types']
  end
end
