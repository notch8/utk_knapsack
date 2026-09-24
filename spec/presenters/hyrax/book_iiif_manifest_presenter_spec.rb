# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::BookIiifManifestPresenter do
  subject(:presenter) { described_class.new(SolrDocument.new(id: 'b1', has_model_ssim: ['Book'])) }

  let(:title) { 'Page one' }
  let(:file_set_doc) do
    SolrDocument.new(id: 'fs1', has_model_ssim: ['FileSet'], mime_type_ssi: 'image/jpeg', schema_version_ssi: '1',
                     title_tesim: [title], sequence_tesim: ['1'], hash_value_tesim: ['abc'],
                     color_space_tesim: [''], date_modified_dtsi: '2026-09-24T05:55:23Z')
  end
  let(:file_set_presenter) do
    Hyrax::IiifManifestPresenter::DisplayImagePresenter.new(file_set_doc).tap do |p|
      allow(p).to receive(:display_content).and_return(instance_double(IIIFManifest::V3::DisplayContent))
    end
  end
  let(:view_definitions) do
    { 'title' => { 'display_label' => { 'default' => 'blacklight.search.fields.show.title_tesim' } },
      'sequence' => { 'display_label' => { 'default' => 'Sequence' } },
      'color_space' => { 'display_label' => { 'default' => 'Color Space' } },
      'date_modified' => { 'display_label' => { 'default' => 'Date Modified' } },
      'hash_value' => { 'display_label' => { 'default' => 'Hash Value' }, 'admin_only' => true } }
  end
  let(:loader) { instance_double(Hyrax::M3SchemaLoader, view_definitions_for: view_definitions.transform_values(&:with_indifferent_access)) }
  let(:item_metadata) { presenter.file_set_presenters.first.item_metadata }
  let(:labels) { item_metadata.map { |m| m['label'].values.flatten.first } }

  before do
    allow(Hyrax::Schema).to receive(:m3_schema_loader).and_return(loader)
    allow(presenter).to receive(:member_presenters).and_return([file_set_presenter])
  end

  it 'reads the file set schema' do
    presenter.file_set_presenters
    expect(loader).to have_received(:view_definitions_for).with(hash_including(schema: 'Hyrax::FileSet'))
  end

  it 'reads the schema once per manifest, not once per page' do
    2.times { presenter.file_set_presenters }
    expect(loader).to have_received(:view_definitions_for).once
  end

  it 'gives each page its filled public fields as IIIF v3 metadata' do
    expect(item_metadata).to include(
      { 'label' => { 'en' => ['Title'] }, 'value' => { 'none' => ['Page one'] } },
      { 'label' => { 'en' => ['Sequence'] }, 'value' => { 'none' => ['1'] } },
      { 'label' => { 'en' => ['Date Modified'] }, 'value' => { 'none' => ['09/24/2026'] } }
    )
  end

  it 'leaves out blank fields' do
    expect(labels).not_to include('Color Space')
  end

  it 'leaves out admin only fields' do
    expect(labels).not_to include('Hash Value')
  end

  context 'with markup in a value' do
    let(:view_definitions) { { 'title' => {} } }
    let(:title) { '<script>alert(1)</script><b onmouseover="x()">Page</b>' }

    it 'scrubs it' do
      expect(item_metadata.first['value']).to eq('none' => ['<b>Page</b>'])
    end
  end

  context 'with an editor only field' do
    let(:view_definitions) { { 'sequence' => { 'editor_only' => true }, 'title' => {} } }

    it 'leaves it out' do
      expect(labels).to eq ['Title']
    end
  end

  context 'with a field hidden from the show page' do
    let(:view_definitions) { { 'sequence' => { 'show_page' => false }, 'title' => {} } }

    it 'leaves it out' do
      expect(labels).to eq ['Title']
    end
  end

  context 'with a featured field' do
    let(:view_definitions) { { 'sequence' => { 'position' => 'featured' }, 'title' => {} } }

    it 'leaves it out' do
      expect(labels).to eq ['Title']
    end
  end

  context 'when no field is filled' do
    let(:view_definitions) { { 'color_space' => {} } }

    it 'gives the page no metadata' do
      expect(item_metadata).to be_nil
    end
  end

  context 'with ranges on, where Hyku copies the Book metadata onto each page' do
    before do
      allow(Flipflop).to receive(:iiif_ranges?).and_return(true)
      allow(presenter).to receive(:manifest_metadata).and_return([{ 'label' => 'Abstract', 'value' => ['Book abstract'] }])
    end

    it 'replaces it with the file set metadata' do
      expect(labels).to eq ['Title', 'Sequence', 'Date Modified']
    end
  end
end
