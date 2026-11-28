# frozen_string_literal: true

module HykuKnapsack
  # Solr keeps the cname a doc was indexed under; this maps any of the current tenant's domains to its current cname.
  module IndexedCname
    def self.current(cname)
      account = Site.account
      return cname if cname.blank? || account.nil?

      account.domain_names.map(&:cname).include?(Account.canonical_cname(cname)) ? account.cname : cname
    end
  end
end
