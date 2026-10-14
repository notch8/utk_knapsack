# frozen_string_literal: true

# OVERRIDE Hyku v7.1.0: leave out the viewingHint Hyku stamps on every manifest, so viewers open
# UTK works one page at a time, and version the manifest so caches drop their paged copies
module HykuKnapsack
  module SinglePageManifest
    LAYOUT = 'single-page'

    module Builder
      def manifest_for(presenter:)
        super.except('viewingHint')
      end
    end

    module Presenter
      def version(**)
        [super, LAYOUT].join('|')
      end
    end
  end
end
