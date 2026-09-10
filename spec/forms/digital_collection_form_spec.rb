# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DigitalCollectionForm do
  it 'builds forms for the configured collection model' do
    expect(described_class.model_class).to eq DigitalCollection
  end

  it 'is the form Hyrax resolves for a DigitalCollection' do
    expect(Hyrax::Forms::ResourceForm.for(resource: DigitalCollection.new)).to be_a described_class
  end

  it 'filters collection access' do
    expect(described_class.ancestors).to include CollectionAccessFiltering
  end
end
