# frozen_string_literal: true

require 'csv'

module Utk
  class UriLookupFailureReport
    HEADERS = %w[uri kind reason attempts last_tried next_retry work_ids].freeze

    Row = Struct.new(:cache, :work_ids, keyword_init: true) do
      delegate :uri, :reason, :attempts, :permanent, :retry_after, :updated_at, to: :cache

      def kind
        permanent ? 'permanent' : 'temporary'
      end
    end

    def rows
      @rows ||= begin
        work_ids = UriCitation.in_current_tenant.order(:work_id).pluck(:uri, :work_id)
                              .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
        UriCache.where(status: UriCache::FAILED, uri: work_ids.keys)
                .map { |cache| Row.new(cache:, work_ids: work_ids[cache.uri]) }
                .sort_by { |row| [row.permanent ? 0 : 1, -row.work_ids.size, row.uri] }
      end
    end

    def to_csv
      CSV.generate do |csv|
        csv << HEADERS
        rows.each do |row|
          csv << [row.uri, row.kind, row.reason, row.attempts, row.updated_at&.iso8601,
                  row.retry_after&.iso8601, row.work_ids.join(' ')]
        end
      end
    end
  end
end
