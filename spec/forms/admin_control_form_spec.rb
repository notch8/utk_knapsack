# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminControlForm do
  it 'builds forms for the configured admin set model' do
    expect(described_class.model_class).to eq AdminControl
  end

  it 'is the form Hyrax resolves for an AdminControl' do
    expect(Hyrax::Forms::ResourceForm.for(resource: AdminControl.new)).to be_a described_class
  end

  it 'filters collection access without mutating the Hyrax form it inherits from' do
    expect(described_class.ancestors).to include CollectionAccessFiltering
    expect(Hyrax::Forms::AdministrativeSetForm.ancestors).not_to include CollectionAccessFiltering
  end
end
