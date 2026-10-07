# frozen_string_literal: true

# OVERRIDE Bulkrax 9.5.1: Bulkrax fills a missing title with [], which on an
# update blanks the record's title and fails validation for a sheet that has
# no title column. Leave it out so the record keeps the title it has.
module Bulkrax
  module ValkyrieObjectFactoryUpdateDecorator
    private

    def transform_attributes(update: false)
      attrs = super
      attrs.delete(:title) if attrs[:title].blank?
      attrs
    end
  end
end

Bulkrax::ValkyrieObjectFactory.prepend(Bulkrax::ValkyrieObjectFactoryUpdateDecorator)
