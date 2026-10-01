# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'hyrax/file_sets/_metadata.html.erb', type: :view do
  let(:solr_document) do
    SolrDocument.new(id: 'fs1',
                     has_model_ssim: ['FileSet'],
                     schema_version_ssi: Hyrax::FlexibleSchema.current_schema_id.to_s,
                     title_tesim: ['Recto'],
                     sequence_tesim: ['1'],
                     file_size_tesim: ['4194304'],
                     file_size_lts: 4_194_304,
                     label_tesim: ['recto.tif'],
                     depositor_tesim: ['depositor@example.com'],
                     bulkrax_identifier_tesim: ['bulkrax-fs1'])
  end
  let(:ability) { Ability.new(nil) }
  let(:presenter) { Hyrax::FileSetPresenter.new(solr_document, ability) }
  let(:labels) { Capybara.string(rendered).all('dt').map { |dt| dt.text.strip.downcase } }

  before do
    allow(Hyrax.config).to receive(:valkyrie_transition?).and_return(false)
    allow(view).to receive(:current_user).and_return(nil)
    assign(:presenter, presenter)
    render 'hyrax/file_sets/metadata'
  end

  it 'renders the filled Hyrax::FileSet profile fields beyond title' do
    expect(labels).to include('title', 'sequence', 'file size', 'label')
  end

  it 'keeps the show_page: false fields hidden' do
    expect(rendered).not_to include('depositor@example.com', 'bulkrax-fs1')
  end
end
