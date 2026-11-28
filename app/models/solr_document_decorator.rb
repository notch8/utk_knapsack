# frozen_string_literal: true

# OVERRIDE Hyku v7.2.0 SolrDocument#link_to_item, #link_to_thumbnail: points this tenant's identifier links at its current cname, not the one indexed with them.
#   Keep: not fixed upstream.
module SolrDocumentDecorator
  private

  def link_to_item
    with_current_cname(super)
  end

  def link_to_thumbnail
    with_current_cname(super)
  end

  def with_current_cname(url)
    indexed = first('account_cname_tesim')
    current = HykuKnapsack::IndexedCname.current(indexed)
    prefix = "https://#{indexed}/"
    return url unless current != indexed && url&.start_with?(prefix)

    "https://#{current}/#{url.delete_prefix(prefix)}"
  end
end

SolrDocument.prepend(SolrDocumentDecorator)
