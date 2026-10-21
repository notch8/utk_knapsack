# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HyraxListenerDecorator do
  let(:file_set) { Hyrax.persister.save(resource: Hyrax::FileSet.new(title: ['page'])) }
  let(:event) { Dry::Events::Event.new(:on_file_characterized, { file_set: }) }

  before { allow(file_set).to receive(:original_file).and_return(instance_double(Hyrax::FileMetadata, pdf?: true)) }

  it 'skips a PDF file set that has no parent work yet' do
    expect { HyraxListener.new.on_file_characterized(event) }.not_to raise_error
  end

  it "turns on the parent work's PDF viewer and download button" do
    work = Hyrax.persister.save(resource: StillImage.new(title: ['parent'], member_ids: [file_set.id]))

    HyraxListener.new.on_file_characterized(event)

    reloaded = Hyrax.query_service.find_by(id: work.id)
    expect([reloaded.show_pdf_viewer, reloaded.show_pdf_download_button]).to eq %w[1 1]
  end
end
