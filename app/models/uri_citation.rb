# frozen_string_literal: true

class UriCitation < ApplicationRecord
  validates :tenant, :work_id, :uri, presence: true

  scope :in_current_tenant, -> { where(tenant: Apartment::Tenant.current) }

  def self.replace_for(work_id, uris)
    tenant = Apartment::Tenant.current
    transaction do
      connection.execute("SELECT pg_advisory_xact_lock(hashtext(#{connection.quote("#{tenant}/#{work_id}")}))")
      where(tenant:, work_id:).delete_all
      rows = uris.map { |uri| { tenant:, work_id:, uri: } }
      insert_all(rows, unique_by: %i[tenant work_id uri]) if rows.any? # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
