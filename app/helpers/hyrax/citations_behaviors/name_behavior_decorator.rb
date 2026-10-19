# frozen_string_literal: true

# OVERRIDE Hyrax v5.3.0 to cite the names in UTK's creators compound, which every citation style reads through all_authors
module Hyrax
  module CitationsBehaviors
    module NameBehaviorDecorator
      def all_authors(work, &block)
        names = Array(work.try(:creators)).filter_map { |entry| entry['name'].presence if entry.is_a?(Hash) }.uniq
        return super if names.empty?

        block ? names.map(&block) : names
      end
    end
  end
end

Hyrax::CitationsBehaviors::NameBehavior.prepend(Hyrax::CitationsBehaviors::NameBehaviorDecorator)
