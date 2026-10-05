# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource Video`
require 'rails_helper'

RSpec.describe 'hyrax/videos/_video.html.erb', type: :view do
  let(:document) { SolrDocument.new(id: 'abc123', title_tesim: ['A Video']) }

  it 'delegates to the shared catalog document partial' do
    stub_template 'catalog/_document.html.erb' => 'CATALOG DOCUMENT PARTIAL'

    render partial: 'hyrax/videos/video', locals: { video: document, video_counter: 1 }

    expect(rendered).to include 'CATALOG DOCUMENT PARTIAL'
  end
end
