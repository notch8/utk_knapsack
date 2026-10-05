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
end
