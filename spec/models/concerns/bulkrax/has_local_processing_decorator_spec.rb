# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Bulkrax::HasLocalProcessingDecorator do
  let(:entry) { Bulkrax::UtkMigrationCsvEntry.new }

  before do
    allow(entry).to receive(:factory_class).and_return(factory_class)
    entry.parsed_metadata = parsed_metadata
    entry.add_local
  end

  context 'with a work type that has PDF viewer fields' do
    let(:factory_class) { Pdf }

    describe 'show_pdf_viewer' do
      context 'when not set' do
        let(:parsed_metadata) { {} }

        it 'defaults to 1' do
          expect(entry.parsed_metadata['show_pdf_viewer']).to eq '1'
        end
      end

      context 'when already set' do
        let(:parsed_metadata) { { 'show_pdf_viewer' => '0' } }

        it 'preserves the existing value' do
          expect(entry.parsed_metadata['show_pdf_viewer']).to eq '0'
        end
      end
    end

    describe 'show_pdf_download_button' do
      context 'when not set' do
        let(:parsed_metadata) { {} }

        it 'defaults to 1' do
          expect(entry.parsed_metadata['show_pdf_download_button']).to eq '1'
        end
      end

      context 'when already set' do
        let(:parsed_metadata) { { 'show_pdf_download_button' => '0' } }

        it 'preserves the existing value' do
          expect(entry.parsed_metadata['show_pdf_download_button']).to eq '0'
        end
      end
    end
  end

  context 'with a work type that gets PDF viewer fields only on its instances' do
    let(:factory_class) do
      Class.new do
        def initialize
          %w[show_pdf_viewer show_pdf_download_button].each { |key| define_singleton_method("#{key}=") { |_| nil } }
        end
      end
    end
    let(:parsed_metadata) { {} }

    it 'defaults the fields to 1' do
      expect(entry.parsed_metadata).to include('show_pdf_viewer' => '1', 'show_pdf_download_button' => '1')
    end
  end

  context 'with a work type that lacks PDF viewer fields' do
    let(:factory_class) { Class.new }
    let(:parsed_metadata) { {} }

    it 'skips the field' do
      expect(entry.parsed_metadata).not_to have_key('show_pdf_viewer')
    end
  end
end
