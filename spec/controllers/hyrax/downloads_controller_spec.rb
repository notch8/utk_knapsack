# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::DownloadsController, type: :controller do
  routes { Hyrax::Engine.routes }

  let(:file_set) { FactoryBot.valkyrie_create(:hyrax_file_set, :authenticated) }
  let(:work) { FactoryBot.valkyrie_create(:still_image, :public, members: [file_set]) }
  let(:thumbnail_path) { Hyrax::DerivativePath.derivative_path_for_reference(file_set.id.to_s, 'thumbnail') }

  before do
    FactoryBot.create(:registered_group)
    work
    FileUtils.mkdir_p(File.dirname(thumbnail_path))
    File.write(thumbnail_path, 'fake-jpeg-content')
  end

  after { FileUtils.rm_f(thumbnail_path) }

  context 'when anonymous, with a public work and an institution file set' do
    it 'serves the thumbnail' do
      get :show, params: { id: file_set.id.to_s, file: 'thumbnail' }
      expect(response).to be_successful
      expect(response.body).to eq 'fake-jpeg-content'
    end

    it 'denies the original file' do
      get :show, params: { id: file_set.id.to_s }
      expect(response).not_to be_successful
    end
  end

  context 'when anonymous, asking for the thumbnail by mime type' do
    let(:file_set) do
      allow(Hyrax).to receive(:storage_adapter).and_return(Valkyrie::StorageAdapter.find(:test_disk))
      FactoryBot.valkyrie_create(:hyrax_file_set, :authenticated, :with_files,
                                 ios: [File.open(Hyrax::Engine.root.join('spec/fixtures/image.png'))])
    end

    before { FileUtils.rm_f(thumbnail_path) }

    it 'denies the original that shares that mime type' do
      mime_type = Hyrax.custom_queries.find_files(file_set:).first.mime_type
      get :show, params: { id: file_set.id.to_s, file: 'thumbnail', mime_type: }
      expect(response).not_to be_successful
    end
  end

  context 'when anonymous, with a suppressed public work' do
    let(:work) do
      FactoryBot.valkyrie_create(:still_image, :public, members: [file_set], state: Hyrax::ResourceStatus::INACTIVE)
    end

    it 'denies the thumbnail' do
      get :show, params: { id: file_set.id.to_s, file: 'thumbnail' }
      expect(response).not_to be_successful
    end
  end

  context 'when anonymous, with a private work' do
    let(:work) { FactoryBot.valkyrie_create(:still_image, members: [file_set]) }

    it 'denies the thumbnail' do
      get :show, params: { id: file_set.id.to_s, file: 'thumbnail' }
      expect(response).not_to be_successful
    end
  end

  context 'when anonymous, with a file set that has no work' do
    let(:work) { nil }

    it 'denies the thumbnail' do
      get :show, params: { id: file_set.id.to_s, file: 'thumbnail' }
      expect(response).not_to be_successful
    end
  end

  context 'when anonymous, with an unknown id' do
    it 'falls through to the stock not-found handling' do
      expect { get :show, params: { id: 'missing', file: 'thumbnail' } }
        .to raise_error(Blacklight::Exceptions::RecordNotFound)
    end
  end

  context 'when signed in' do
    let(:user) { FactoryBot.create(:user) }

    before { sign_in user }

    it 'can download the institution file set' do
      expect(controller.current_ability.can?(:download, file_set.id.to_s)).to be true
    end
  end

  context 'with a Range request for a public file on disk' do
    let(:fixture) { Hyrax::Engine.root.join('spec/fixtures/image.png') }
    let(:bytes) { File.binread(fixture) }
    let(:file_set) do
      allow(Hyrax).to receive(:storage_adapter).and_return(Valkyrie::StorageAdapter.find(:test_disk))
      FactoryBot.valkyrie_create(:hyrax_file_set, :public, :with_files, ios: [File.open(fixture)])
    end

    it 'serves the requested bytes from the middle of the file' do
      request.headers['Range'] = 'bytes=100-149'
      get :show, params: { id: file_set.id.to_s }

      expect(response.status).to eq 206
      expect(response.body.b).to eq bytes[100, 50]
      expect(response.headers['Content-Range']).to eq "bytes 100-149/#{bytes.bytesize}"
    end

    it 'caps an open-ended range rather than sending the rest of the file' do
      stub_const('HykuKnapsack::ValkyrieRangeDownloadsDecorator::MAX_RANGE_BYTES', 64)
      request.headers['Range'] = 'bytes=10-'
      get :show, params: { id: file_set.id.to_s }

      expect(response.body.b).to eq bytes[10, 64]
      expect(response.headers['Content-Range']).to eq "bytes 10-73/#{bytes.bytesize}"
    end

    it 'answers a range that starts past the end of the file as unsatisfiable' do
      request.headers['Range'] = "bytes=#{bytes.bytesize + 10}-"
      get :show, params: { id: file_set.id.to_s }

      expect(response.status).to eq 416
      expect(response.body).to be_empty
      expect(response.headers['Content-Range']).to eq "bytes */#{bytes.bytesize}"
      expect(response.headers['Content-Length']).to eq '0'
    end

    it 'answers a reversed range as unsatisfiable' do
      request.headers['Range'] = 'bytes=100-10'
      get :show, params: { id: file_set.id.to_s }

      expect(response.status).to eq 416
    end

    it 'serves the last bytes of the file for a suffix range' do
      request.headers['Range'] = 'bytes=-20'
      get :show, params: { id: file_set.id.to_s }

      expect(response.status).to eq 206
      expect(response.body.b).to eq bytes[-20..]
      expect(response.headers['Content-Range']).to eq "bytes #{bytes.bytesize - 20}-#{bytes.bytesize - 1}/#{bytes.bytesize}"
    end

    it 'answers a range it cannot parse as unsatisfiable' do
      request.headers['Range'] = 'bytes=0-9,20-29'
      get :show, params: { id: file_set.id.to_s }

      expect(response.status).to eq 416
    end
  end

  describe 'a Range request for a file in S3' do
    let(:ranged) { StringIO.new('ranged') }
    let(:object) do
      instance_double(Shrine::Storage::S3, open: ranged, object: instance_double(Aws::S3::Object, content_length: 1000))
    end
    let(:io) { Valkyrie::Storage::Shrine::DelayedDownload.new(object, 'fs/abc') }
    let(:file) { Valkyrie::StorageAdapter::StreamFile.new(id: 'shrine://fs/abc', io:) }

    before { controller.set_response!(ActionDispatch::TestResponse.new) }

    it 'sizes the file with a HEAD and fetches only the requested bytes' do
      request.headers['Range'] = 'bytes=900-'

      expect(controller.send(:send_range_valkyrie, file:)).to eq 'ranged'
      expect(object).to have_received(:open).once
      expect(object).to have_received(:open).with('fs/abc', rewindable: false, range: 'bytes=900-999')
      expect(ranged).to be_closed
    end

    it 'opens nothing when the range starts past the end of the file' do
      request.headers['Range'] = 'bytes=2000-'

      expect(controller.send(:send_range_valkyrie, file:)).to eq ''
      expect(object).not_to have_received(:open)
    end
  end
end
