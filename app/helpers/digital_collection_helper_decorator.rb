# frozen_string_literal: true

# OVERRIDE Hyku v7.2.0 (f908dc6e) digital-collection-theme
#   - read the theme's names from UTK's creators compound and its summaries from abstract
#   - render a result list on a show page, such as a collection's members, with the search result fields
#     rather than the show page fields; Blacklight's document_presenter picks its presenter by action
#     TEMPORARY: delete dc_profile_result_fields, dc_result_field_shown? and dc_result_presenter when
#     samvera/hyku#3444 is in the pinned submodule (refs notch8/utk_knapsack#439)
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

  def dc_profile_result_fields(document)
    # OVERRIDE: dc_result_presenter instead of document_presenter
    rows = dc_result_presenter(document).fields_to_render.filter_map do |field_name, _config, presenter|
      next if field_name.to_s.start_with?('title_')

      value = presenter.render
      [dc_result_field_key(field_name), dc_result_row(index_field_label(document, field_name), markdown(value))] if value.present?
    end
    extra = document.collection? ? [:works, dc_works_count_label(document)] : [:part_of, dc_part_of_links(document)]
    extra.last.present? ? rows << [extra.first, dc_result_row(t("digital_collection.search.results.fields.#{extra.first}"), extra.last)] : rows
  end

  def dc_result_field_shown?(document, field_name)
    return true unless Hyrax.config.flexible?

    @dc_result_fields_shown ||= {}
    # OVERRIDE: dc_result_presenter instead of document_presenter
    shown = @dc_result_fields_shown[document.id] ||= dc_result_presenter(document).fields_to_render.map { |name, _config, _presenter| name.to_s }
    shown.include?(field_name)
  end

  def dc_result_presenter(document)
    blacklight_config.view_config(document_index_view_type).document_presenter_class.new(document, self)
  end

  def dc_creators_in_results?(document)
    return true unless Hyrax.config.flexible?

    options = dc_profile_view_definitions(document)[:creators]&.with_indifferent_access
    options.present? && options[:search_results] != false && !(options[:admin_only] && !current_user&.admin?)
  end
end

DigitalCollectionHelper.prepend(DigitalCollectionHelperDecorator)
