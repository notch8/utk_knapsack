# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::ThumbnailPathServiceDecorator do
  let(:file_set) { Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ['A file set'])) }

  def attach(use, mime_type)
    file = Hyrax.persister.save(resource: Hyrax::FileMetadata.new(file_identifier: Valkyrie::ID.new("disk:///tmp/#{use}"),
                                                                  file_set_id: file_set.id, mime_type:, pcdm_use: [use]))
    file_set.file_ids += [file.id]
    Hyrax.persister.save(resource: file_set)
    file
  end

  def thumbnail_path_for(resource)
    Hyrax::ValkyrieIndexer.for(resource:).thumbnail_path
  end

  def image(name)
    ActionController::Base.helpers.image_path(name)
  end

  it 'gives an audio file set the audio icon' do
    attach(Hyrax::FileMetadata::Use::ORIGINAL_FILE, 'audio/mpeg')

    expect(thumbnail_path_for(Hyrax.query_service.find_by(id: file_set.id))).to eq image('audio.png')
  end

  it 'keeps the default icon for a file set with no thumbnail that is not audio' do
    attach(Hyrax::FileMetadata::Use::ORIGINAL_FILE, 'text/xml')

    expect(thumbnail_path_for(Hyrax.query_service.find_by(id: file_set.id))).to eq image('default.png')
  end

  it "keeps an image file set's own thumbnail" do
    attach(Hyrax::FileMetadata::Use::ORIGINAL_FILE, 'image/jpeg')
    thumbnail = attach(Hyrax::FileMetadata::Use::THUMBNAIL_IMAGE, 'image/jpeg')
    allow(Hyrax.custom_queries).to receive(:find_thumbnail).and_return(thumbnail)
    resource = Hyrax.query_service.find_by(id: file_set.id)

    expect(thumbnail_path_for(resource)).to eq Hyrax::Engine.routes.url_helpers.download_path(resource.id, file: 'thumbnail')
  end

  it 'keeps the audio icon on an audio work' do
    attach(Hyrax::FileMetadata::Use::ORIGINAL_FILE, 'audio/mpeg')
    work = Hyrax.persister.save(resource: Audio.new(title: ['An audio work'], thumbnail_id: file_set.id, member_ids: [file_set.id]))

    expect(thumbnail_path_for(work)).to eq image('audio.png')
  end

  it 'does not look up file metadata for a work with no thumbnail' do
    work = Hyrax.persister.save(resource: Audio.new(title: ['An audio work']))
    allow(Hyrax::FileSetTypeService).to receive(:new).and_call_original

    thumbnail_path_for(work)

    expect(Hyrax::FileSetTypeService).not_to have_received(:new)
  end
end
