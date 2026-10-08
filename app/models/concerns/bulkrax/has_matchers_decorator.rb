# frozen_string_literal: true

# OVERRIDE Bulkrax 9.5.1: the knapsack's default field mapping splits every column on
# "|", so a blank cell reaches a single-valued field as an empty list, which
# Bulkrax stringifies to "[]". Return nil instead so importer defaults apply.
module Bulkrax
  module HasMatchersDecorator
    def single_metadata(content)
      return if content.is_a?(Array) && content.all?(&:blank?)

      super
    end
  end
end

Bulkrax::HasMatchers.prepend(Bulkrax::HasMatchersDecorator)
