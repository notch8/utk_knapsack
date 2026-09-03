# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource StillImage`
require 'rails_helper'

RSpec.describe 'hyrax/still_images/_still_image.html.erb', type: :view do
  let(:document) { SolrDocument.new(id: 'abc123', title_tesim: ['A Still Image']) }

  it 'delegates to the shared catalog document partial' do
    stub_template 'catalog/_document.html.erb' => 'CATALOG DOCUMENT PARTIAL'

    render partial: 'hyrax/still_images/still_image', locals: { still_image: document, still_image_counter: 1 }

    expect(rendered).to include 'CATALOG DOCUMENT PARTIAL'
  end
end
