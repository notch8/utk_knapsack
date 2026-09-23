# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaViewerFormBehavior do
  let(:form_classes) do
    [AudioForm, BookForm, CompoundObjectForm, NewspaperForm, PdfForm, StillImageForm, VideoForm]
  end

  it 'is included in all seven UTK work type forms' do
    form_classes.each do |klass|
      expect(klass.ancestors).to include(described_class), "expected #{klass} to include #{described_class}"
    end
  end

  context 'when per_work_media_viewer? is disabled' do
    before { allow(Flipflop).to receive(:per_work_media_viewer?).and_return(false) }

    it 'removes :media_viewer from primary and secondary terms' do
      form = PdfForm.new(Pdf.new)

      expect(form.primary_terms).not_to include(:media_viewer)
      expect(form.secondary_terms).not_to include(:media_viewer)
    end
  end

  context 'when per_work_media_viewer? is enabled' do
    before { allow(Flipflop).to receive(:per_work_media_viewer?).and_return(true) }

    it 'keeps :media_viewer in secondary terms' do
      form = PdfForm.new(Pdf.new)

      expect(form.secondary_terms).to include(:media_viewer)
    end
  end
end
