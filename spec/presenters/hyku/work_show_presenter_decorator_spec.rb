# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyku::WorkShowPresenterDecorator do
  let(:solr_data) do
    {
      'id' => 'abc-123',
      'has_model_ssim' => ['Pdf'],
      'title_tesim' => ['Test PDF']
    }
  end
  let(:solr_document) { SolrDocument.new(solr_data) }
  let(:ability) { Ability.new(nil) }
  let(:presenter) { Hyku::WorkShowPresenter.new(solr_document, ability) }

  describe '#show_pdf_viewer' do
    context 'when the Solr field is absent' do
      it 'defaults to true' do
        expect(presenter.show_pdf_viewer).to be true
      end
    end

    context 'when show_pdf_viewer_bsi is explicitly true' do
      before { solr_data['show_pdf_viewer_bsi'] = true }

      it 'returns true' do
        expect(presenter.show_pdf_viewer).to be true
      end
    end

    context 'when show_pdf_viewer_bsi is false' do
      before { solr_data['show_pdf_viewer_bsi'] = false }

      it 'defaults to true because the dynamic method path makes false indistinguishable from absent' do
        expect(presenter.show_pdf_viewer).to be true
      end
    end
  end

  describe '#show_pdf_download_button' do
    context 'when the Solr field is absent' do
      it 'defaults to true' do
        expect(presenter.show_pdf_download_button).to be true
      end
    end

    context 'when show_pdf_download_button_bsi is false' do
      before { solr_data['show_pdf_download_button_bsi'] = false }

      it 'defaults to true because the dynamic method path makes false indistinguishable from absent' do
        expect(presenter.show_pdf_download_button).to be true
      end
    end
  end
end
