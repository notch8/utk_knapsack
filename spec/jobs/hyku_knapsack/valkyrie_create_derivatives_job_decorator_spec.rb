# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::ValkyrieCreateDerivativesJobDecorator do
  let(:job) { ValkyrieCreateDerivativesJob.new }
  let(:file_set) { double('file_set', id: 'fs-1', rdf_type:) }
  let(:rdf_type) { [] }
  let(:pdf) { false }
  let(:file_metadata) do
    double('file_metadata', file_identifier: 'disk://x', video?: false, audio?: false, pdf?: pdf)
  end
  let(:derivative_service) { double('derivative_service', create_derivatives: true) }

  before do
    allow(Hyrax.query_service).to receive(:find_by).with(id: 'fs-1').and_return(file_set)
    allow(Hyrax.custom_queries).to receive(:find_parent_work).and_return(double(thumbnail_id: nil))
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
end
