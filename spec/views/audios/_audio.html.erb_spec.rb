# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource Audio`
require 'rails_helper'

RSpec.describe 'hyrax/audios/_audio.html.erb', type: :view do
  let(:document) { SolrDocument.new(id: 'abc123', title_tesim: ['An Audio']) }

  it 'delegates to the shared catalog document partial' do
    stub_template 'catalog/_document.html.erb' => 'CATALOG DOCUMENT PARTIAL'

    render partial: 'hyrax/audios/audio', locals: { audio: document, audio_counter: 1 }

    expect(rendered).to include 'CATALOG DOCUMENT PARTIAL'
  end
end
