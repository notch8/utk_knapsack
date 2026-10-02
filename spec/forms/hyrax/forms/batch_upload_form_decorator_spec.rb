# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::Forms::BatchUploadFormDecorator do
  let(:form) { Hyrax::Forms::BatchUploadForm.allocate.tap { |f| f.payload_concern = 'StillImage' } }

  it 'requires the fields the metadata profile requires' do
    expect(form.required_fields).to include(:title, :provider, :primary_identifier)
  end

  it 'reads the fields for the batch’s admin set' do
    allow(form).to receive(:model).and_return(double(admin_set_id: 'batch-admin-set'))
    allow(Hyrax::Forms::ResourceForm).to receive(:for).and_call_original

    form.required_fields

    expect(Hyrax::Forms::ResourceForm).to have_received(:for)
      .with(resource: an_instance_of(StillImage), admin_set_id: 'batch-admin-set')
  end
end
