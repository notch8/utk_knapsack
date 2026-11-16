# frozen_string_literal: true

# OVERRIDE Hyrax 5.3.0 (ad34cd7b) to link bare URLs in sanitized rich text, as the default renderer does
module Hyrax
  module Renderers
    module HtmlAttributeRendererDecorator
      private

      def sanitize_rich_text(value)
        auto_link_sanitized(super)
      end

      def auto_link_sanitized(html)
        auto_link(html, sanitize: false)
      end
    end
  end
end

Hyrax::Renderers::HtmlAttributeRenderer.prepend(Hyrax::Renderers::HtmlAttributeRendererDecorator)
