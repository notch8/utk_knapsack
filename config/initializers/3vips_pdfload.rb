# frozen_string_literal: true

require 'ruby-vips'

Vips.block_untrusted(true)
Vips.block('VipsForeignLoadPdf', false)
