# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UtkMigrationCharacterizationJob do
  let(:metadata) { double('file_metadata', id: 'fm-1', file: nil) }
  let(:service) { class_double(Hyrax::Characterization::ValkyrieCharacterizationService) }
  let(:instance) { instance_double(Hyrax::Characterization::ValkyrieCharacterizationService, characterize: true) }

  let(:persister) { double('persister', save: metadata) }
  let(:publisher) { double('publisher', publish: nil) }
  let(:queries) { double('custom_queries', find_file_metadata_by: metadata) }
  let(:characterization_args) { {} }

  before do
    allow(Hyrax).to receive_messages(custom_queries: queries, persister:, publisher:)
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
end
