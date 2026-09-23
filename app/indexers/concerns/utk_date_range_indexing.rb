# frozen_string_literal: true

##
# Index a numeric year for every work, so the catalog can offer one date range
# facet covering both creation and publication.
module UtkDateRangeIndexing
  SOLR_FIELD = 'date_range_isim'
  DATE_PROPERTIES = %i[date_created_d date_issued_d].freeze

  def to_solr(*args, **kwargs, &block)
    super(*args, **kwargs, &block).tap do |solr_doc|
      years = HykuKnapsack::DateRangeYears.call(DATE_PROPERTIES.map { |property| resource.try(property) })

      solr_doc[SOLR_FIELD] = years if years.any?
    end
  end
end
