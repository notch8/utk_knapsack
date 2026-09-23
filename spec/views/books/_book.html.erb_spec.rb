# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource Book`
require 'rails_helper'

RSpec.describe 'hyrax/books/_book.html.erb', type: :view do
  let(:document) { SolrDocument.new(id: 'abc123', title_tesim: ['A Book']) }

  it 'delegates to the shared catalog document partial' do
    stub_template 'catalog/_document.html.erb' => 'CATALOG DOCUMENT PARTIAL'

    render partial: 'hyrax/books/book', locals: { book: document, book_counter: 1 }

    expect(rendered).to include 'CATALOG DOCUMENT PARTIAL'
  end
end
