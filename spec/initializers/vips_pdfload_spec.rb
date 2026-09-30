# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'config/initializers/3vips_pdfload.rb' do
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
end
