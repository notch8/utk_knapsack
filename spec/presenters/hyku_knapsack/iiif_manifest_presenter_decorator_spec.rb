# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::IiifManifestPresenterDecorator do
  def index_file_set(id, rdf_type)
    Hyrax::SolrService.add({ id:, has_model_ssim: ['FileSet'], read_access_group_ssim: ['public'], rdf_type_tesim: [rdf_type] },
                           commit: true)
  end

  subject(:presenter) do
    Hyrax::IiifManifestPresenter.new(SolrDocument.new(id: 'work-504', has_model_ssim: ['Video'],
                                                      member_ids_ssim: %w[page-504 thumbnail-504])).tap do |p|
      p.hostname = 'example.com'
      p.ability = Ability.new(nil)
    end
  end

  before do
    index_file_set('page-504', 'http://pcdm.org/use#IntermediateFile')
    index_file_set('thumbnail-504', 'http://pcdm.org/use#ThumbnailImage')
  end

  it 'leaves a supplied thumbnail image out of the members' do
    expect(presenter.member_presenters.map(&:id)).to eq ['page-504']
  end
end
