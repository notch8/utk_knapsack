# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0 HykuIndexing#extract_text_from_plain_text_files and
# #extract_text_from_pdf_directly (still reached only from #extract_text_from_child_works): collect
# the member file sets' text from their Solr documents instead of downloading each text/plain
# original from storage on every reindex of the parent
module HykuKnapsack
  module HykuIndexingDecorator
    private

    def extract_text_from_plain_text_files(object)
      file_set_texts(object).reject { |doc| pdf?(doc) }.flat_map { |doc| doc[:text] }
    end

    def extract_text_from_pdf_directly(object)
      texts = file_set_texts(object).select { |doc| pdf?(doc) }.flat_map { |doc| doc[:text] }
      texts.presence
    end

    def pdf?(doc)
      Hyrax.config.derivative_mime_type_mappings[:pdf].include?(doc[:mime_type])
    end

    def file_set_texts(object)
      (@file_set_texts ||= {})[object.id] ||= file_set_full_texts(object)
    end

    def file_set_full_texts(object)
      member_ids = Array(object.member_ids).map(&:to_s).reject(&:blank?)
      return [] if member_ids.empty?

      docs = Hyrax::SolrService.query(
        "{!terms f=id}#{member_ids.join(',')}",
        fq: file_set_model_filter,
        fl: 'id,mime_type_ssi,all_text_tsimv',
        rows: member_ids.length,
        method: :post
      ).index_by { |doc| doc['id'].to_s }

      member_ids.filter_map do |id|
        doc = docs[id]
        next unless doc

        { mime_type: doc['mime_type_ssi'], text: Array(doc['all_text_tsimv']).select(&:present?) }
      end
    end
  end
end

HykuIndexing.prepend(HykuKnapsack::HykuIndexingDecorator)
