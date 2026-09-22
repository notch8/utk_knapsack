# frozen_string_literal: true

# OVERRIDE Hyku 7.1.0 SolrDocument#show_pdf_viewer, #show_pdf_download_button
# to default true when the field was never persisted (Bulkrax imports).
module SolrDocumentDecorator
  def show_pdf_viewer
    value = pdf_viewer_field_value('show_pdf_viewer')
    return true if value.nil?
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def show_pdf_download_button
    value = pdf_viewer_field_value('show_pdf_download_button')
    return true if value.nil?
    ActiveModel::Type::Boolean.new.cast(value)
  end

  private

  def pdf_viewer_field_value(field)
    if key?("#{field}_bsi")
      self["#{field}_bsi"]
    else
      self["#{field}_tsi"] ||
        Array.wrap(self["#{field}_tesim"]).first
    end
  end
end

SolrDocument.prepend(SolrDocumentDecorator)
