# frozen_string_literal: true

# OVERRIDE Hyku v7.2.0 (f908dc6e) to show a work's resource type by its indexed label
#   - theme_type_label shows the label, falling back to the work type name rather than the stored URI
#   - theme_resource_type_label gives the label alone, for a badge with no fallback
# TEMPORARY: delete when samvera/hyku#3445 is in the pinned submodule (refs notch8/utk_knapsack#262)
module ThemeHelperDecorator
  def theme_type_label(object)
    theme_resource_type_label(object) || theme_model_label(object)
  end

  def theme_resource_type_label(object)
    document = object.try(:solr_document) || object
    stored = Array(document.try(:[], 'resource_type_tesim')).first
    label = Array(document.try(:[], Hyrax::ControlledVocabularyFieldValues.label_key('resource_type_tesim'))).first
    label unless label.blank? || label == stored
  end
end

ThemeHelper.prepend(ThemeHelperDecorator)
