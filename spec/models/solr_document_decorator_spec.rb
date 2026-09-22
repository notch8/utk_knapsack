# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SolrDocumentDecorator do
  let(:document) { SolrDocument.new(solr_data) }

  describe '#show_pdf_viewer' do
    context 'when no pdf viewer field is indexed' do
      let(:solr_data) { { 'id' => 'abc123' } }

      it 'defaults to true' do
        expect(document.show_pdf_viewer).to be true
      end
    end

    context 'when show_pdf_viewer_bsi is true' do
      let(:solr_data) { { 'id' => 'abc123', 'show_pdf_viewer_bsi' => true } }

      it 'returns true' do
        expect(document.show_pdf_viewer).to be true
      end
    end

    context 'when show_pdf_viewer_bsi is false' do
      let(:solr_data) { { 'id' => 'abc123', 'show_pdf_viewer_bsi' => false } }

      it 'returns false' do
        expect(document.show_pdf_viewer).to be false
      end
    end

    context 'when show_pdf_viewer_tesim is "1"' do
      let(:solr_data) { { 'id' => 'abc123', 'show_pdf_viewer_tesim' => ['1'] } }

      it 'returns true' do
        expect(document.show_pdf_viewer).to be true
      end
    end

    context 'when show_pdf_viewer_tesim is "0"' do
      let(:solr_data) { { 'id' => 'abc123', 'show_pdf_viewer_tesim' => ['0'] } }

      it 'returns false' do
        expect(document.show_pdf_viewer).to be false
      end
    end
  end

  describe '#show_pdf_download_button' do
    context 'when no download button field is indexed' do
      let(:solr_data) { { 'id' => 'abc123' } }

      it 'defaults to true' do
        expect(document.show_pdf_download_button).to be true
      end
    end

    context 'when show_pdf_download_button_bsi is true' do
      let(:solr_data) { { 'id' => 'abc123', 'show_pdf_download_button_bsi' => true } }

      it 'returns true' do
        expect(document.show_pdf_download_button).to be true
      end
    end

    context 'when show_pdf_download_button_bsi is false' do
      let(:solr_data) { { 'id' => 'abc123', 'show_pdf_download_button_bsi' => false } }

      it 'returns false' do
        expect(document.show_pdf_download_button).to be false
      end
    end
  end
end
