# frozen_string_literal: true

# Hyrax resolves a controlled property's labels through
# `Hyrax.config.controlled_vocabulary_label_service`, but only for a property it can see
# in the schema. A compound's sub-properties live inside a `_json_ss` blob, which its
# per-attribute authority rules have no way to reach, so the creators and contributors a
# work carries keep their raw URIs.
#
# This resolves those, leaving every flat property to Hyrax.
module UtkUriLabelIndexing
  def to_solr(*args, **kwargs, &block)
    super(*args, **kwargs, &block).tap { |solr_doc| resolve_compound_uris(solr_doc) }
  end

  private

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
