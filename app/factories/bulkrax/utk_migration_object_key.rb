# frozen_string_literal: true

require 'active_support/core_ext/digest/uuid'

module Bulkrax
  module UtkMigrationObjectKey
    def self.for(file_set_id:, sha1:)
      "#{file_set_id}/#{Digest::UUID.uuid_v5(Digest::UUID::URL_NAMESPACE, "#{file_set_id}/#{sha1}")}"
    end
  end
end
