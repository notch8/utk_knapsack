# frozen_string_literal: true

require 'rails_helper'
require 'hyrax/specs/shared_specs/hydra_works'

RSpec.describe AdminControl do
  subject(:admin_set) { described_class.new }

  it_behaves_like 'a Hyrax::AdministrativeSet'

  it 'is the configured admin set model' do
    expect(Hyrax.config.admin_set_class).to eq described_class
  end

  it 'is flexible' do
    expect(described_class).to be_flexible
  end
end
