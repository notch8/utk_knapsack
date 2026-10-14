# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::IiifManifestPresenter::DisplayImagePresenter do
  let(:transcript) do
    FactoryBot.valkyrie_create(:hyrax_file_set, :public, title: ['English captions'], language: ['en'])
  end
  let(:video) { FactoryBot.valkyrie_create(:hyrax_file_set, :public, transcript_ids: [transcript.id.to_s]) }

  subject(:presenter) do
    solr = Hyrax::Indexers::ResourceIndexer.for(resource: video).to_solr.merge('mime_type_ssi' => 'video/mp4')
    described_class.new(SolrDocument.new(solr)).tap do |presenter|
      presenter.hostname = 'example.com'
      presenter.ability = Ability.new(nil)
    end
  end

  before do
    vtt = Hyrax.persister.save(resource: Hyrax::FileMetadata.new(file_set_id: transcript.id, mime_type: 'text/vtt',
                                                                 pcdm_use: [Hyrax::FileMetadata::Use::ORIGINAL_FILE]))
    transcript.file_ids = [vtt.id]
    Hyrax.index_adapter.save(resource: Hyrax.persister.save(resource: transcript))
  end

  it 'annotates an A/V canvas with the VTT its transcript_ids name' do
    annotation = presenter.annotation_content.sole

    expect(annotation.format).to eq 'text/vtt'
    expect(annotation.language).to eq 'en'
    expect(annotation.label).to eq 'English captions'
    expect(annotation.body_id).to eq "http://example.com/transcripts/#{transcript.id}.vtt"
  end
end
