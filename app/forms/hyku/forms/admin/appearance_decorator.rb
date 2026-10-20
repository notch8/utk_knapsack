# frozen_string_literal: true

# OVERRIDE Hyku to start every UTK site, and its Restore Default buttons, on UTK's brand colors and Montserrat
module Hyku
  module Forms
    module Admin
      module AppearanceDecorator
        UTK_COLORS = {
          'footer_link_color' => '#ffffff',
          'footer_link_hover_color' => '#ffffff',
          'header_and_footer_background_color' => '#4b4b4b',
          'header_and_footer_text_color' => '#ffffff',
          'default_button_text_color' => '#4b4b4b',
          'link_color' => '#006c93',
          'link_hover_color' => '#005c7d',
          'primary_button_background_color' => '#ffffff',
          'primary_button_border_color' => '#ff8200',
          'primary_button_hover_color' => '#ffffff',
          'primary_button_text_color' => '#006c93'
        }.freeze

        UTK_FONTS = {
          'body_font' => 'Montserrat:400,500,600,700',
          'headline_font' => 'Montserrat:400,500,600,700'
        }.freeze

        def self.prepended(base)
          base.default_colors = base.default_colors.merge(UTK_COLORS)
          base.default_fonts = base.default_fonts.merge(UTK_FONTS)
        end
      end
    end
  end
end

Hyku::Forms::Admin::Appearance.prepend(Hyku::Forms::Admin::AppearanceDecorator)
