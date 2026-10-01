# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UtkMigrationCharacterizationJob do
  let(:metadata) do
    double('file_metadata', id: 'fm-1', file: nil, original_file?: true, file_set_id: 'fs-1',
                            pdf?: true, audio?: false, original_filename: 'memoir.pdf')
  end
  let(:file_set) { double('file_set', id: 'fs-1', rdf_type: ['http://pcdm.org/use#ServiceFile'], thumbnail: nil) }
  let(:service) { class_double(Hyrax::Characterization::ValkyrieCharacterizationService) }
  let(:instance) { instance_double(Hyrax::Characterization::ValkyrieCharacterizationService, characterize: true) }

  let(:persister) { double('persister', save: metadata) }
  let(:publisher) { double('publisher', publish: nil) }
  let(:queries) { double('custom_queries', find_file_metadata_by: metadata) }
  let(:characterization_args) { {} }

  before do
    allow(Hyrax).to receive_messages(custom_queries: queries, persister:, publisher:)
    allow(Hyrax.query_service).to receive(:find_by).with(id: 'fs-1').and_return(file_set)
    allow(Hyrax.config).to receive(:characterization_service).and_return(service)
    allow(service).to receive(:new) { |**kwargs|
                        characterization_args.merge!(kwargs)
                        instance
                      }
  end

  it 'characterizes and persists what characterization wrote' do
    described_class.perform_now('fm-1')

    expect(instance).to have_received(:characterize)
    expect(persister).to have_received(:save).with(resource: metadata)
  end

  # Hyrax's own default is `mapper.merge(original_checksum: :checksum)`, which
  # lets FITS overwrite the sha1. That digest is `digest_ssim`, which is the
  # identifier the external IIIF service is addressed by.
  it 'keeps FITS away from the checksum by passing the unmerged mapper' do
    described_class.perform_now('fm-1')

    expect(characterization_args[:parser_mapping]).not_to include(original_checksum: :checksum)
  end

  it 'passes the characterization options rather than falling back to the CLI' do
    described_class.perform_now('fm-1')

    expect(characterization_args).to include(Hyrax.config.characterization_options)
  end

  it 'reindexes the file set so width and height reach Solr' do
    described_class.perform_now('fm-1')

    expect(publisher).to have_received(:publish).with('file.metadata.updated', any_args)
  end

  it 'does not republish characterization, which would regenerate derivatives' do
    described_class.perform_now('fm-1')

    expect(publisher).not_to have_received(:publish).with('file.characterized', any_args)
  end

  describe 'the thumbnail' do
    it 'is enqueued once characterization has recorded the real mime type' do
      described_class.perform_now('fm-1')

      expect(ValkyrieCreateDerivativesJob).to have_been_enqueued.with('fs-1', 'fm-1')
    end

    it 'is not enqueued when the file set already has one' do
      allow(file_set).to receive(:thumbnail).and_return(double('thumbnail'))
      described_class.perform_now('fm-1')

      expect(ValkyrieCreateDerivativesJob).not_to have_been_enqueued
    end

    it 'is not enqueued for a file that should have none' do
      allow(metadata).to receive_messages(pdf?: false, original_filename: 'scan.tiff')
      described_class.perform_now('fm-1')

      expect(ValkyrieCreateDerivativesJob).not_to have_been_enqueued
    end

    it 'is not enqueued when the row characterized is not the original' do
      allow(metadata).to receive(:original_file?).and_return(false)
      described_class.perform_now('fm-1')

      expect(ValkyrieCreateDerivativesJob).not_to have_been_enqueued
      expect(Hyrax.query_service).not_to have_received(:find_by)
    end
  end

  context 'with the real characterization service' do
    let(:service) { Hyrax::Characterization::ValkyrieCharacterizationService }
    let(:metadata) { Hyrax::FileMetadata.new(original_filename: 'memoir.pdf', recorded_size: ['0'], file_set_id: 'fs-1') }

    before do
      allow(service).to receive(:new).and_call_original
      allow(metadata).to receive(:file).and_return(StringIO.new('%PDF'))
      allow(Hydra::FileCharacterization).to receive(:characterize)
        .and_return('<fits><fileinfo><size>71245608</size></fileinfo></fits>')
    end

    it 'records the size FITS measured rather than the one legacy recorded' do
      described_class.perform_now('fm-1')

      expect(metadata.recorded_size).to eq(['71245608'])
    end
  end
end
