# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::Renderers::HtmlAttributeRendererDecorator do
  subject(:markup) { Nokogiri::HTML.fragment(Hyrax::Renderers::HtmlAttributeRenderer.new(:abstract, [value]).render) }

  context 'with a bare URL in the text' do
    let(:value) { 'Finding aid at https://lib.utk.edu/aid. More soon.' }

    it 'links it' do
      expect(markup.css('a').map { |a| [a['href'], a.text] }).to eq([['https://lib.utk.edu/aid', 'https://lib.utk.edu/aid']])
    end
  end

  context 'with a URL already inside a link' do
    let(:value) { '<p>See <a href="https://lib.utk.edu/aid">https://lib.utk.edu/aid</a>.</p>' }

    it 'keeps the one link' do
      expect(markup.css('a').size).to eq(1)
    end
  end

  context 'with markup that is not allowed' do
    let(:value) { '<script>alert(1)</script>https://lib.utk.edu/aid' }

    it 'still strips it' do
      expect(markup.css('script')).to be_empty
    end
  end
end
