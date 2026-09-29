# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::ValkyrieCreateDerivativesJobDecorator do
  let(:job) { ValkyrieCreateDerivativesJob.new }
  let(:file_set) { double('file_set', id: 'fs-1', rdf_type:, thumbnail:) }
  let(:thumbnail) { double('thumbnail') }
  let(:rdf_type) { [] }
  let(:pdf) { false }
  let(:file_metadata) do
    double('file_metadata', file_identifier: 'disk://x', original_filename: 'scan.tiff', video?: false, audio?: false, pdf?: pdf)
  end
  let(:derivative_service) { double('derivative_service', create_derivatives: true) }
  let(:parent) { Pdf.new(id: 'work-1', title: ['parent']) }
  let(:persister) { instance_double(Valkyrie::Persistence::Postgres::Persister) }
  let(:index_adapter) { instance_double(Valkyrie::Indexing::Solr::IndexingAdapter, save: nil) }

  before do
    allow(Hyrax.query_service).to receive(:find_by).with(id: 'fs-1').and_return(file_set)
    allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-1').and_return(parent)
    allow(job).to receive(:acquire_lock_for).and_yield
    allow(Hyrax.custom_queries).to receive(:find_parent_work).with(resource: file_set).and_return(parent)
    allow(Hyrax).to receive_messages(persister:, index_adapter:)
    allow(persister).to receive(:save) { |resource:| resource }
    allow(Hyrax.custom_queries).to receive(:find_file_metadata_by).with(id: 'fm-1').and_return(file_metadata)
    allow(Hyrax.storage_adapter).to receive(:find_by).and_return(double(disk_path: '/tmp/x'))
    allow(Hyrax::DerivativeService).to receive(:for).with(file_metadata).and_return(derivative_service)
    job.perform('fs-1', 'fm-1')
  end

  context 'with an intermediate file' do
    let(:rdf_type) { ['http://pcdm.org/use#IntermediateFile'] }

    it { expect(derivative_service).to have_received(:create_derivatives) }
  end

  context 'with preservation and intermediate types' do
    let(:rdf_type) { ['http://pcdm.org/use#PreservationFile', 'https://pcdm.org/use#IntermediateFile'] }

    it { expect(derivative_service).to have_received(:create_derivatives) }
  end

  context 'with a preservation-only file' do
    let(:rdf_type) { ['http://pcdm.org/use#PreservationFile'] }

    it { expect(Hyrax::DerivativeService).not_to have_received(:for) }
  end

  context 'with a bare, lowercase intermediate type' do
    let(:rdf_type) { ['intermediatefile'] }

    it { expect(derivative_service).to have_received(:create_derivatives) }
  end

  context 'with a type that only contains the intermediate term' do
    let(:rdf_type) { ['http://example.org/terms#NotIntermediateFile'] }

    it { expect(Hyrax::DerivativeService).not_to have_received(:for) }
  end

  context 'with a PDF that is not an intermediate file' do
    let(:rdf_type) { ['http://pcdm.org/use#ServiceFile'] }
    let(:pdf) { true }

    it { expect(derivative_service).to have_received(:create_derivatives) }
  end

  describe 'the parent work' do
    let(:rdf_type) { ['http://pcdm.org/use#IntermediateFile'] }

    context 'when it has no thumbnail yet' do
      it 'is pointed at the file set as thumbnail and representative, saved and reindexed' do
        expect(parent.thumbnail_id).to eq 'fs-1'
        expect(parent.representative_id).to eq 'fs-1'
        expect(persister).to have_received(:save).with(resource: parent)
        expect(index_adapter).to have_received(:save).with(resource: parent)
      end
    end

    context 'while another job or the relationship pass may be saving it' do
      it 'is re-read and saved under the lock Bulkrax uses for the same parent' do
        expect(job).to have_received(:acquire_lock_for).with('work-1')
        expect(Hyrax.query_service).to have_received(:find_by).with(id: 'work-1')
      end
    end

    context 'when the job produced no thumbnail, as for audio' do
      let(:thumbnail) { nil }

      it 'is not pointed at a file set that cannot show one' do
        expect(parent.thumbnail_id).to be_nil
        expect(persister).not_to have_received(:save)
      end
    end

    context 'when it already has a representative but no thumbnail' do
      let(:parent) { Pdf.new(id: 'work-1', title: ['parent'], representative_id: 'fs-0') }

      it 'gains the thumbnail and keeps its representative' do
        expect(parent.thumbnail_id).to eq 'fs-1'
        expect(parent.representative_id).to eq 'fs-0'
      end
    end

    context 'when it already shows another file set' do
      let(:parent) { Pdf.new(id: 'work-1', title: ['parent'], thumbnail_id: 'fs-0', representative_id: 'fs-0') }

      it 'is left alone' do
        expect(parent.thumbnail_id).to eq 'fs-0'
        expect(persister).not_to have_received(:save)
        expect(index_adapter).not_to have_received(:save)
      end
    end

    context 'when the file set has no parent yet' do
      let(:parent) { nil }

      it 'is not looked for twice' do
        expect(persister).not_to have_received(:save)
      end
    end

    context 'when the guard rejects the file' do
      let(:rdf_type) { ['http://pcdm.org/use#PreservationFile'] }

      it 'is not touched' do
        expect(Hyrax.custom_queries).not_to have_received(:find_parent_work)
        expect(persister).not_to have_received(:save)
      end
    end
  end
end
