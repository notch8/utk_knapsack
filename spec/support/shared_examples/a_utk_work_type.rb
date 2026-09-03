# frozen_string_literal: true

RSpec.shared_examples 'a UTK work type' do
  it 'does not prepend OrderAlready onto a flexible work type' do
    expect(described_class.ancestors.first).to eq described_class
  end

  it 'routes creator through OrderAlready under flexible metadata' do
    work = described_class.new

    expect(OrderAlready::InputOrderSerializer).to receive(:serialize).with(['Zeta, Z']).and_call_original

    work.creator = ['Zeta, Z']
  end

  it 'splits PDFs into a registered work type' do
    expect(Hyrax.config.registered_curation_concern_types)
      .to include(described_class.new.iiif_print_config.pdf_split_child_model.to_s)
  end

  it 'is registered as a curation concern' do
    expect(Hyrax.config.registered_curation_concern_types).to include(described_class.to_s)
  end
end
