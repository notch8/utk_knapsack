# frozen_string_literal: true

# OVERRIDE Hyku v7.2.1 (634bd285) - merge rows past Blacklight's max_per_page, which caps
#   builder.rows at 100 and left the homepage without collections sorting after the 100th,
#   and start at 0 so a page param cannot skip any
module HykuKnapsack
  module HomepageControllerDecorator
    private

    def collections(rows: 6)
      Hyrax::CollectionsService.new(self).search_results do |builder|
        builder.merge(rows:, start: 0, sort: 'title_ssi asc')
      end
    rescue Blacklight::Exceptions::ECONNREFUSED, Blacklight::Exceptions::InvalidRequest
      []
    end
  end
end

Hyrax::HomepageController.prepend(HykuKnapsack::HomepageControllerDecorator)
