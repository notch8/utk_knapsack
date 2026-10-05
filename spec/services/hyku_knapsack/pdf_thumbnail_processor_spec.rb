# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HykuKnapsack::PdfThumbnailProcessor do
  let(:directives) { Hyrax.config.derivative_options[:pdf].first.merge(url: 'thumbnail') }
  let(:output) { StringIO.new }
  let(:output_file_service) { ->(io, _directives) { output.write(io.read) } }

  def fixture(name)
    HykuKnapsack::Engine.root.join('spec', 'fixtures', 'pdfs', name).to_s
  end

  def render(processor_class, name, directives = self.directives)
    output.truncate(0)
    output.rewind
    processor_class.new(fixture(name), directives, output_file_service:).process
    Vips::Image.new_from_buffer(output.string, '')
  end

  def thumbnail(...)
    image = render(...)
    [image.width, image.height]
  end

  def color(...)
    pixel = render(...).getpoint(10, 10)
    %i[red green blue][pixel.index(pixel.max)]
  end

  it 'renders a page declaring 60,912 x 86,400 points at thumbnail size in seconds' do
    Timeout.timeout(10) { expect(thumbnail(described_class, 'oversized_page.pdf')).to eq [676, 959] }
  end

  it 'renders the first page by default' do
    expect(color(described_class, 'two_pages.pdf', directives.except(:layer))).to eq :red
  end

  it 'renders the page the layer directive names' do
    expect(color(described_class, 'two_pages.pdf', directives.merge(layer: 1))).to eq :blue
  end

  it "matches ImageMagick's thumbnail size for an ordinary page" do
    expect(thumbnail(described_class, 'portrait.pdf'))
      .to eq thumbnail(Hydra::Derivatives::Processors::Image, 'portrait.pdf')
  end

  it "matches ImageMagick's orientation for a rotated page" do
    expect(thumbnail(described_class, 'rotated.pdf'))
      .to eq(thumbnail(Hydra::Derivatives::Processors::Image, 'rotated.pdf')).and eq [676, 522]
  end

  it 'takes its bounds from the directives' do
    expect(thumbnail(described_class, 'portrait.pdf', directives.merge(size: '100x100'))).to eq [77, 100]
  end

  it "honors ImageMagick's shrink-only flag" do
    expect(thumbnail(described_class, 'portrait.pdf', directives.merge(size: '2000x2000>'))).to eq [612, 792]
  end

  it 'writes a JPEG' do
    thumbnail(described_class, 'portrait.pdf')
    expect(output.string.byteslice(0, 3).bytes).to eq [0xFF, 0xD8, 0xFF]
  end

  it 'is the processor for PDF derivatives only' do
    expect(Hydra::Derivatives::PdfDerivatives.processor_class).to eq described_class
    expect(Hydra::Derivatives::ImageDerivatives.processor_class).to eq Hydra::Derivatives::Processors::Image
  end
end
