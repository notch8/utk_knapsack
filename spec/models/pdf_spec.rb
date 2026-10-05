# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource Pdf`
require 'rails_helper'
require 'hyrax/specs/shared_specs/hydra_works'

RSpec.describe Pdf do
  subject(:work) { described_class.new }

  it_behaves_like 'a Hyrax::Work'
  it_behaves_like 'a UTK work type'
end
