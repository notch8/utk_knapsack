# frozen_string_literal: true

module Utk
  class IndexingContext < ActiveSupport::CurrentAttributes
    attribute :failed_uris
  end
end
