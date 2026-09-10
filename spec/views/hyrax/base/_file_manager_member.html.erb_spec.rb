# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'hyrax/base/_file_manager_member.html.erb', type: :view do
  let(:sequence) { ['3'] }
  let(:model) { 'Hyrax::FileSet' }
  let(:document) do
    SolrDocument.new(
      id: 'fs1',
      has_model_ssim: [model],
      title_tesim: ['Page three'],
      schema_version_ssi: '1',
      sequence_sim: sequence
    )
  end
  let(:node) { Hyrax::FileSetPresenter.new(document, nil) }

  before do
    without_partial_double_verification do
      allow(view).to receive(:contextual_path).and_return('/edit')
    end
    stub_template 'hyrax/base/_file_manager_thumbnail.html.erb' => ''
    stub_template 'hyrax/base/_file_manager_attributes.html.erb' => ''
    stub_template 'hyrax/base/_file_manager_member_resource_options.html.erb' => ''
  end

  def rendered_li
    render partial: 'hyrax/base/file_manager_member', locals: { node: }
    Nokogiri::HTML.fragment(rendered).at_css('li')
  end

  it 'carries the sequence the file manager sorts on' do
    expect(rendered_li['data-sequence']).to eq '3'
  end

  context 'when the sequence carries several values' do
    let(:sequence) { ['7', '3'] }

    it 'carries the lowest' do
      expect(rendered_li['data-sequence']).to eq '3'
    end
  end

  context 'when the sequence is absent' do
    let(:sequence) { [] }

    it 'carries an empty attribute rather than a position' do
      expect(rendered_li['data-sequence']).to eq ''
    end
  end

  context 'when the sequence holds the literal "[]" the legacy index carries' do
    let(:sequence) { ['[]'] }

    it 'carries an empty attribute rather than a position' do
      expect(rendered_li['data-sequence']).to eq ''
    end
  end

  context 'when the member is a child work rather than a file set' do
    let(:model) { 'Book' }
    let(:node) { Hyrax::WorkShowPresenter.new(document, nil) }

    it 'carries the sequence too, so both sort in one list' do
      expect(rendered_li['data-sequence']).to eq '3'
    end

    it 'renders at all, though its flexible label reader returns an array' do
      expect(rendered_li.at_css('.order-filename')).to be_nil
    end
  end

  context 'when the member is a file set, whose label is a plain string' do
    let(:document) do
      SolrDocument.new(id: 'fs1', has_model_ssim: [model], title_tesim: ['Page three'],
                       schema_version_ssi: '1', sequence_sim: sequence, label_tesim: ['page3.tif'])
    end

    it 'still renders the truncated label' do
      expect(rendered_li.at_css('.order-filename').text).to include 'page3.tif'
    end
  end

  it 'still carries the reorder id the save path reads' do
    expect(rendered_li['data-reorder-id']).to eq 'fs1'
  end
end
