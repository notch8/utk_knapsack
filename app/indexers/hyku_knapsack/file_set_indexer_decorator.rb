# frozen_string_literal: true

# OVERRIDE Hyku: index a PDF's text from its extracted text derivative instead of downloading
# the original on every reindex
module HykuKnapsack
  module FileSetIndexerDecorator
    private

    def all_text(object)
      return @all_text if defined?(@all_text)

      @all_text = super
    end

    def pdf_text
      text = all_text(resource)
      text.dup.force_encoding(Encoding::UTF_8).scrub('').squish if text.present?
    end
  end
end

Hyku::Indexers::FileSetIndexer.prepend(HykuKnapsack::FileSetIndexerDecorator)
