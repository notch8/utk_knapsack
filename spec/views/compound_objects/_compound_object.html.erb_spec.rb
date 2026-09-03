# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource CompoundObject`
require 'rails_helper'

RSpec.describe 'hyrax/compound_objects/_compound_object.html.erb', type: :view do
  let(:document) { SolrDocument.new(id: 'abc123', title_tesim: ['A Compound Object']) }

  it 'delegates to the shared catalog document partial' do
    stub_template 'catalog/_document.html.erb' => 'CATALOG DOCUMENT PARTIAL'

    render partial: 'hyrax/compound_objects/compound_object', locals: { compound_object: document, compound_object_counter: 1 }

    expect(rendered).to include 'CATALOG DOCUMENT PARTIAL'
  end
end
