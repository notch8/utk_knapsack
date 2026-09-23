# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::FlexibilityDecorator do
  let(:resource) { Pdf.new(attributes) }
  let(:attributes) { {} }

  describe '#show_pdf_viewer' do
    context 'when not set' do
      it 'defaults to true' do
        expect(resource.show_pdf_viewer).to be true
      end
    end

    context 'when explicitly true' do
      let(:attributes) { { show_pdf_viewer: true } }

      it 'returns true' do
        expect(resource.show_pdf_viewer).to be true
      end
    end

    context 'when explicitly false' do
      let(:attributes) { { show_pdf_viewer: false } }

      it 'preserves false' do
        expect(resource.show_pdf_viewer).to be false
      end
    end
  end

  describe '#show_pdf_download_button' do
    context 'when not set' do
      it 'defaults to true' do
        expect(resource.show_pdf_download_button).to be true
      end
    end

    context 'when explicitly false' do
      let(:attributes) { { show_pdf_download_button: false } }

      it 'preserves false' do
        expect(resource.show_pdf_download_button).to be false
      end
    end
  end

  describe 'non-Pdf work types' do
    it 'defaults on Audio' do
      expect(Audio.new.show_pdf_viewer).to be true
    end

    it 'defaults on StillImage' do
      expect(StillImage.new.show_pdf_viewer).to be true
    end
  end
end
