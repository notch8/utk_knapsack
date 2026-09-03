# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource Pdf`
require 'rails_helper'

RSpec.describe 'hyrax/pdfs/_pdf.html.erb', type: :view do
  let(:document) { SolrDocument.new(id: 'abc123', title_tesim: ['A Pdf']) }

  it 'delegates to the shared catalog document partial' do
    stub_template 'catalog/_document.html.erb' => 'CATALOG DOCUMENT PARTIAL'

    render partial: 'hyrax/pdfs/pdf', locals: { pdf: document, pdf_counter: 1 }

    expect(rendered).to include 'CATALOG DOCUMENT PARTIAL'
  end
end
