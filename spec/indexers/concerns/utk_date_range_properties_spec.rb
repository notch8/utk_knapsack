# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UtkDateRangeProperties do
  let(:base_indexer) do
    Class.new do
      attr_reader :resource

      def initialize(resource:)
        @resource = resource
      end

      def to_solr(*_args, **_kwargs)
        {}
      end
    end
  end

  let(:indexer_class) do
    Class.new(base_indexer) do
      include DateRangeIndexing
      include UtkDateRangeProperties
    end
  end
  let(:work) { Struct.new(:date_created_d, :date_issued_d, :date_other_d, keyword_init: true) }

  def years(**dates)
    indexer_class.new(resource: work.new(**dates)).to_solr[DateRangeIndexing::SOLR_FIELD]
  end

  it 'indexes the creation and publication years' do
    expect(years(date_created_d: '1911', date_issued_d: '1968-10-09')).to eq [1911, 1968]
  end

  it 'leaves other dates out of the facet' do
    expect(years(date_other_d: '1850')).to be_nil
  end
end
