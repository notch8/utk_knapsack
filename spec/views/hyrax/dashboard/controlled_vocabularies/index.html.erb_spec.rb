# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'hyrax/dashboard/controlled_vocabularies/index.html.erb', type: :view do
  include_context 'with knapsack view paths'

  let(:can_manage) { true }
  let(:can_create) { true }

  before do
    assign(:controlled_vocabularies, [])
    allow(view).to receive(:can?).with(:manage, :controlled_vocabularies).and_return(can_manage)
    allow(view).to receive(:can?).with(:create, :new_controlled_vocabulary).and_return(can_create)
    render
  end

  it 'links a vocabulary manager to the unresolved labels page beside New vocabulary' do
    expect(rendered).to have_css('.text-right a.btn-outline-secondary[href="/dashboard/uri_lookup_failures"] + a.btn-primary')
    expect(rendered).to have_link('Unresolved labels')
  end

  context 'when the manager cannot create vocabularies' do
    let(:can_create) { false }

    it 'still offers the unresolved labels link' do
      expect(rendered).to have_link('Unresolved labels', href: '/dashboard/uri_lookup_failures')
    end
  end

  context 'for someone who can only view vocabularies' do
    let(:can_manage) { false }
    let(:can_create) { false }

    it 'shows no action row' do
      expect(rendered).to have_no_css('.mb-3.text-right')
    end
  end
end
