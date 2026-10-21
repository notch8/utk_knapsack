# frozen_string_literal: true

# The search bar's work type menu, which limits a search to one of the tenant's enabled work types.
module SearchWorkTypeHelper
  WORK_TYPE_FILTER = :has_model_ssim

  # @return [Array<Array(String, String)>] label and value of each enabled work type, in registration order
  def search_work_type_options
    enabled = Array(Site.instance.available_works)
    Hyrax.config.curation_concerns
         .select { |klass| enabled.include?(klass.to_s) }
         .map { |klass| [work_type_facet_label(klass.to_s), klass.to_s] }
  end

  # Advanced search sends its choice as f_inclusive. The menu holds one type, so several show as All.
  # @return [String, nil] the work type the current search is limited to
  def chosen_search_work_type
    chosen = %i[f f_inclusive].flat_map { |key| Array(search_state.params.dig(key, WORK_TYPE_FILTER)) }.uniq
    chosen.first if chosen.one?
  end

  # A type the menu does not offer, such as collections picked from the sidebar, still shows by name,
  # since the next search submits it.
  def chosen_search_work_type_label
    chosen = chosen_search_work_type
    chosen ? work_type_facet_label(chosen) : t('hyrax.search.form.option.all.label_short')
  end

  # The menu submits the work type itself, so a new choice replaces the old one instead of narrowing to no results.
  # @return [Hash] the current search's filters, without the work type
  def search_params_without_work_type
    search_state.params_for_search.except(:q, :search_field, :qt, :page, :utf8).tap do |carried|
      %i[f f_inclusive].each { |key| carried[key] = carried[key].except(WORK_TYPE_FILTER) if carried[key] }
    end
  end
end
