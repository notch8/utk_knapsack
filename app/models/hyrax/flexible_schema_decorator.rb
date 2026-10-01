# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0: a saved profile replaces the request-scoped schema memos
module Hyrax
  module FlexibleSchemaDecorator
    extend ActiveSupport::Concern

    included do
      after_commit { Hyrax::Current.flexible_schema = nil }
    end
  end
end

Hyrax::FlexibleSchema.include(Hyrax::FlexibleSchemaDecorator)
