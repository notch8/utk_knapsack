# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'IIIF file set metadata' do
  Hyrax.config.registered_curation_concern_types.each do |type|
    it "is on for #{type}'s pages" do
      expect("Hyrax::#{type.pluralize}Controller".constantize.iiif_file_set_metadata).to be true
    end
  end
end
