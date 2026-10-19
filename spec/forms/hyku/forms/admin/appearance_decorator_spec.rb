# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyku::Forms::Admin::AppearanceDecorator do
  subject(:form) { Hyku::Forms::Admin::Appearance.new }

  let(:utk_colors) do
    {
      link_color: '#4b4b4b',
      link_hover_color: '#4b4b4b',
      primary_button_background_color: '#4b4b4b',
      primary_button_border_color: '#4b4b4b',
      primary_button_hover_color: '#4b4b4b',
      primary_button_text_color: '#ffffff',
      default_button_text_color: '#4b4b4b',
      header_and_footer_background_color: '#4b4b4b',
      header_and_footer_text_color: '#ffffff',
      footer_link_color: '#ffffff',
      footer_link_hover_color: '#ffffff'
    }
  end

  it "shows UTK's colors on the Appearance page when none are saved" do
    expect(utk_colors.keys.index_with { |field| form.public_send(field) }).to eq(utk_colors)
  end

  it "restores UTK's colors, not Hyku's, as each color's default" do
    expect(form.default_colors).to include(utk_colors.stringify_keys)
  end

  it 'starts headings and body text on Montserrat with every weight the UTK design uses' do
    expect([form.body_font, form.headline_font]).to all(eq('Montserrat:400,500,600,700'))
    expect([form.font_body_family, form.font_headline_family]).to all(eq('Montserrat'))
    expect(form.font_import_body_url).to eq('fonts.googleapis.com/css?family=Montserrat:400,500,600,700')
  end

  it "keeps a color an admin saved over UTK's default" do
    ContentBlock.update_block(name: 'link_color', value: '#123456')

    expect(Hyku::Forms::Admin::Appearance.new.link_color).to eq('#123456')
  end

  it "gives the Digital Collection theme UTK's message and visited link colors from the gray link" do
    helpers = ApplicationController.helpers
    link = form.link_color

    expect(helpers.dc_darken_until(link, '#ffffff', 4.5)).to eq('#4b4b4b')
    expect(helpers.dc_status_color(:success, link)).to eq('#3f6d40')
    expect(helpers.dc_status_color(:danger, link)).to eq('#9f453f')
    expect(helpers.dc_visited_color(link, helpers.dc_mix('#000000', '#ffffff', 0.92))).to eq('#4b4b4b')
  end
end
