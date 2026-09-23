# frozen_string_literal: true

FactoryBot.define do
  factory :uri_cache do
    uri { 'http://id.loc.gov/authorities/names/n2017180154' }
    value { 'University of Tennessee' }
  end
end
