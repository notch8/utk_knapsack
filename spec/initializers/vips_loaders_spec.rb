# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'config/initializers/3vips_loaders.rb' do
  let(:initializer) { HykuKnapsack::Engine.root.join('config', 'initializers', '3vips_loaders.rb').to_s }
  let(:jp2) { HykuKnapsack::Engine.root.join('spec', 'fixtures', 'images', 'page.jp2').to_s }

  def with_external_iiif_url(url)
    original = ENV.fetch('EXTERNAL_IIIF_URL', nil)
    ENV['EXTERNAL_IIIF_URL'] = url
    load initializer
    yield
  ensure
    ENV['EXTERNAL_IIIF_URL'] = original
    load initializer
  end

  it 'lets libvips load PDFs' do
    pdf = HykuKnapsack::Engine.root.join('spec', 'fixtures', 'pdfs', 'portrait.pdf').to_s

    expect(Vips::Image.pdfload(pdf).width).to eq 612
  end

  it 'leaves the other untrusted loaders blocked' do
    %i[matload svgload].each do |loader|
      expect { Vips::Image.public_send(loader, '/nonexistent') }
        .to raise_error(Vips::Error, /#{loader}: operation is blocked/)
    end
  end

  it 'lets libvips load JPEG 2000 when riiif serves images' do
    with_external_iiif_url(nil) do
      expect(Vips::Image.jp2kload(jp2).width).to eq 40
    end
  end

  it 'keeps JPEG 2000 blocked when an external IIIF server serves images' do
    with_external_iiif_url('https://iiif.example.org/iiif/2') do
      expect { Vips::Image.jp2kload(jp2) }.to raise_error(Vips::Error, /jp2kload: operation is blocked/)
    end
  end
end
