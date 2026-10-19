# frozen_string_literal: true

# OVERRIDE Hyku digital-collection-theme to read the theme's names from UTK's creators compound and its summaries from abstract
module DigitalCollectionHelperDecorator
  def dc_creator_names(record)
    document = record.is_a?(Blacklight::Document) ? record : record.solr_document
    names = Array(document['creators_name_tesim']).compact_blank.uniq
    return super if names.empty?

    shown = record.is_a?(Blacklight::Document) ? dc_creators_in_results?(document) : dc_profile_shows?(record, :creators)
    shown ? names : []
  end

  def dc_summary(record)
    document = record.is_a?(Blacklight::Document) ? record : record.solr_document
    summary = Array(document['abstract_tesim']).compact_blank
    return super if summary.empty?

    record.is_a?(Blacklight::Document) || dc_profile_shows?(record, :abstract) ? summary : []
  end

  def dc_work_shown_elsewhere
    "#{super}, .attribute-abstract"
  end

  private

  def dc_creators_in_results?(document)
    return true unless Hyrax.config.flexible?

    options = dc_profile_view_definitions(document)[:creators]&.with_indifferent_access
    options.present? && options[:search_results] != false && !(options[:admin_only] && !current_user&.admin?)
  end
end

DigitalCollectionHelper.prepend(DigitalCollectionHelperDecorator)
