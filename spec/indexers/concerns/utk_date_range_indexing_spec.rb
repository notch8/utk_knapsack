# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UtkDateRangeIndexing do
  let(:base_indexer) do
    Class.new do
      attr_reader :resource

      def initialize(resource:)
        @resource = resource
      end

      def to_solr(*_args, **_kwargs)
        { 'title_tesim' => ['Untouched'] }
      end
    end
  end

  let(:indexer_class) { Class.new(base_indexer) { include UtkDateRangeIndexing } }
  let(:work) { Struct.new(:date_created_d, :date_issued_d, keyword_init: true) }

  let(:solr_field) { described_class::SOLR_FIELD }

  def index(**dates)
    indexer_class.new(resource: work.new(**dates)).to_solr
  end

  it 'indexes the creation year' do
    expect(index(date_created_d: '1911')[solr_field]).to eq [1911]
  end

  it 'indexes the publication year' do
    expect(index(date_issued_d: '1968-10-09')[solr_field]).to eq [1968]
  end

  it 'indexes both years, so one slider covers creation and publication' do
    expect(index(date_created_d: '1940', date_issued_d: '1945')[solr_field]).to eq [1940, 1945]
  end

  it 'indexes one year when both properties agree' do
    expect(index(date_created_d: '1940', date_issued_d: '1940-06')[solr_field]).to eq [1940]
  end

  it 'reads an array-valued property' do
    expect(index(date_created_d: ['1911'])[solr_field]).to eq [1911]
  end

  it 'omits the field when neither property has a value' do
    expect(index).not_to have_key solr_field
  end

  it 'omits the field when the values are the "[]" sentinel Hyrax writes for an empty attribute' do
    expect(index(date_created_d: '[]', date_issued_d: '[]')).not_to have_key solr_field
  end

  it 'omits the field when no value parses' do
    expect(index(date_created_d: 'n.d.')).not_to have_key solr_field
  end

  it 'indexes what it can when only one property parses' do
    expect(index(date_created_d: '[]', date_issued_d: '1962-11')[solr_field]).to eq [1962]
  end

  it 'leaves the rest of the document alone' do
    expect(index(date_created_d: '1911')['title_tesim']).to eq ['Untouched']
  end

  context 'with a resource that has neither property, as a non-flexible model would not' do
    let(:work) { Struct.new(:title, keyword_init: true) }

    it 'omits the field rather than raising' do
      expect(index(title: ['No dates here'])).not_to have_key solr_field
    end
  end
end
