# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::M3SchemaLoaderDecorator do
  let(:version) { Hyrax::FlexibleSchema.current_schema_id }

  def flexible_schema_queries
    count = 0
    counter = lambda do |*, payload|
      count += 1 if payload[:sql].include?('"hyrax_flexible_schemas"')
    end
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { yield }
    count
  end

  def load_pdf_schema
    Hyrax::Schema.m3_schema_loader.attributes_for(schema: 'Pdf', version:)
  end

  before { Hyrax::Current.reset }

  it 'reads a schema version once per request' do
    version
    expect(flexible_schema_queries { 3.times { load_pdf_schema } }).to eq(1)
  end

  it 'reads it again in the next request' do
    load_pdf_schema
    Hyrax::Current.reset
    version
    expect(flexible_schema_queries { load_pdf_schema }).to eq(1)
  end

  it 'keeps a single-digit query count when a work with members is reordered' do
    members = Array.new(7) { Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ['page'])) }
    work = Hyrax.persister.save(resource: Pdf.new(title: ['Pages'], provider: ['UTK'], rights_statement: ['In Copyright'],
                                                  primary_identifier: ['pages'], has_work_type: ['Text'],
                                                  member_ids: members.map(&:id)))
    Hyrax::Current.reset

    queries = flexible_schema_queries do
      form = Hyrax::Forms::ResourceForm.for(resource: Hyrax.query_service.find_by(id: work.id))
      form.validate('member_ids' => members.reverse.map(&:id).map(&:to_s), 'version' => form.version)
      result = Hyrax::Transactions::Container['change_set.update_work'].call(form)
      expect(result).to be_success
    end

    expect(queries).to be < 10
  end
end
