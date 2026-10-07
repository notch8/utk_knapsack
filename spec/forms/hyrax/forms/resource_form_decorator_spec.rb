# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::Forms::ResourceFormDecorator do
  let(:attributes) { { title: ['The Art of Arrowmont'], provider: ['UT Libraries'], primary_identifier: ['arrowmont:3d'] } }

  def build_form
    Hyrax::Forms::ResourceForm.for(resource: DigitalCollection.new).prepopulate!
  end

  context 'when another form of the same class is built while one is in flight' do
    let!(:in_flight) { build_form }

    before { build_form.send(:reset_flexible_definitions!) }

    it 'keeps the in-flight form’s profile fields' do
      in_flight.validate(attributes)

      expect(in_flight.title).to eq ['The Art of Arrowmont']
    end

    it 'keeps the in-flight form’s required fields' do
      in_flight.validate(attributes.merge(title: []))

      expect(in_flight.errors[:title]).to include "can't be blank"
    end
  end

  it 'reports the form class’s own name' do
    expect(build_form.class.name).to eq 'DigitalCollectionForm'
  end

  it 'prints as the form class in logs' do
    expect(build_form.class.inspect).to eq 'DigitalCollectionForm'
    expect(build_form.class.to_s).to eq 'DigitalCollectionForm'
  end

  it 'is still an instance of the form class' do
    expect(build_form).to be_a DigitalCollectionForm
  end

  it 'keeps a required field set on the form class' do
    form_class = Class.new(DigitalCollectionForm) { property :depositor }
    form_class.required_fields += [:depositor]

    expect(form_class.new(resource: DigitalCollection.new)).to be_required(:depositor)
  end

  it 'adds no profile field to the form class' do
    build_form

    expect(DigitalCollectionForm.definitions.keys).not_to include 'title'
  end

  it 'builds a form for a non-flexible resource from the form class itself' do
    form_class = Hyrax::Forms::ResourceForm(Hyrax::Resource)

    expect(form_class.new(resource: Hyrax::Resource.new).class).to eq form_class
  end
end
