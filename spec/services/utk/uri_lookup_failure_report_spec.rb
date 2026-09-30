# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Utk::UriLookupFailureReport do
  subject(:report) { described_class.new }

  let(:tenant) { Apartment::Tenant.current }

  def cite(uri, *work_ids, tenant: Apartment::Tenant.current)
    work_ids.each { |work_id| UriCitation.create!(tenant:, work_id:, uri:) }
  end

  def fail_uri(uri, permanent:, **attrs)
    create(:uri_cache, uri:, status: 'failed', value: nil, permanent:, reason: permanent ? 'Not Found(404)' : '(499)',
                       attempts: 1, retry_after: 1.hour.from_now, **attrs)
  end

  before do
    fail_uri('http://example.com/temporary-many', permanent: false)
    fail_uri('http://example.com/permanent-one', permanent: true)
    fail_uri('http://example.com/permanent-two', permanent: true)
    create(:uri_cache, uri: 'http://example.com/resolved', value: 'Fine')

    cite('http://example.com/temporary-many', 'w1', 'w2', 'w3')
    cite('http://example.com/permanent-one', 'w1')
    cite('http://example.com/permanent-two', 'w2', 'w4')
    cite('http://example.com/resolved', 'w1')
  end

  it 'lists failed URIs this tenant cites, permanent first, then by how many works cite them' do
    expect(report.rows.map { |row| [row.uri, row.work_ids] }).to eq [
      ['http://example.com/permanent-two', %w[w2 w4]],
      ['http://example.com/permanent-one', %w[w1]],
      ['http://example.com/temporary-many', %w[w1 w2 w3]]
    ]
  end

  it 'leaves out failures only another tenant cites' do
    fail_uri('http://example.com/elsewhere', permanent: true)
    cite('http://example.com/elsewhere', 'x1', tenant: 'another-tenant')

    expect(report.rows.map(&:uri)).not_to include 'http://example.com/elsewhere'
  end

  it 'writes the rows as CSV' do
    csv = CSV.parse(report.to_csv, headers: true)

    expect(csv.headers).to eq %w[uri kind reason attempts last_tried next_retry work_ids]
    expect(csv.first.to_h).to include('uri' => 'http://example.com/permanent-two', 'kind' => 'permanent',
                                      'reason' => 'Not Found(404)', 'attempts' => '1', 'work_ids' => 'w2 w4')
  end
end
