# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0
#   - HykuIndexing#extract_text_from_plain_text_files and #extract_text_from_pdf_directly (still
#     reached only from #extract_text_from_child_works): collect the member file sets' text from
#     their Solr documents instead of downloading each text/plain original from storage on every
#     reindex of the parent
#   - HykuIndexing#to_solr: sort Published Date on the earliest day `date_created_d` allows instead
#     of the display `date_created` string, leaving undated works without a value so they sort last
module HykuKnapsack
  module HykuIndexingDecorator
    def to_solr(*args, **kwargs, &block)
      super.tap do |solr_doc|
        # OVERRIDE: replace the display string Hyku copies into the Published Date sort field
        published = earliest_date_created(resource)
        published ? solr_doc[CatalogController.created_field] = published.iso8601 : solr_doc.delete(CatalogController.created_field)
      end
    end

    private

    def earliest_date_created(object)
      Array(object.try(:date_created_d)).filter_map { |value| earliest_day(Date.edtf(value.to_s)) }.min
    end

    def earliest_day(edtf)
      return edtf.to_date if edtf.is_a?(Date)

      edtf.try(:min) unless edtf.try(:earlier?)
    end

    def extract_text_from_plain_text_files(object)
      file_set_docs(object).reject(&:pdf?).flat_map { |doc| full_text(doc) }
    end

    def extract_text_from_pdf_directly(object)
      file_set_docs(object).select(&:pdf?).flat_map { |doc| full_text(doc) }.presence
    end

    def full_text(doc)
      Array(doc['all_text_tsimv']).select(&:present?)
    end

    def file_set_docs(object)
      (@file_set_docs ||= {})[object.id] ||= member_file_set_docs(object)
    end

    def member_file_set_docs(object)
      member_ids = Array(object.member_ids).map(&:to_s).reject(&:blank?)
      return [] if member_ids.empty?

      docs = Hyrax::SolrService.query(
        "{!terms f=id}#{member_ids.join(',')}",
        fq: file_set_model_filter,
        fl: 'id,mime_type_ssi,all_text_tsimv',
        rows: member_ids.length,
        method: :post
      ).index_by { |doc| doc['id'].to_s }

      member_ids.filter_map { |id| docs[id] }.map { |doc| ::SolrDocument.new(doc) }
    end
  end
end

HykuIndexing.prepend(HykuKnapsack::HykuIndexingDecorator)
