# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource StillImage`
require 'rails_helper'
require 'hyrax/specs/shared_specs/hydra_works'

RSpec.describe StillImage do
  subject(:work) { described_class.new }

  it_behaves_like 'a Hyrax::Work'

  it 'does not prepend OrderAlready onto a flexible work type' do
    expect(described_class.ancestors.first).to eq described_class
  end

  it 'splits PDFs into a registered work type' do
    expect(Hyrax.config.registered_curation_concern_types)
      .to include(described_class.new.iiif_print_config.pdf_split_child_model.to_s)
  end
end
