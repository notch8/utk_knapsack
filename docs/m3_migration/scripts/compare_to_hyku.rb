#!/usr/bin/env ruby
# frozen_string_literal: true

# Compares the migrated UTK profile against Hyku's default m3 profile, property
# by property, for every property Hyku declares.
#
#   ruby scripts/compare_to_hyku.rb [hyku_profile.yaml] [migrated_profile.yaml]
#
# Both arguments are optional. They default to Hyku's profile in the submodule
# and the converted profile in ../files, resolved from this script's own
# location so it runs from any working directory.

require 'yaml'

FILES_DIR = File.expand_path('../files', __dir__)
KNAPSACK_ROOT = File.expand_path('../../..', __dir__)

HYKU = ARGV[0] || File.join(KNAPSACK_ROOT, 'hyrax-webapp/config/metadata_profiles/m3_profile.yaml')
MINE = ARGV[1] || File.join(FILES_DIR, 'migrated_profile.yaml')

[HYKU, MINE].each do |path|
  raise(ArgumentError, "profile not found: #{path}") unless File.exist?(path)
end

hyku = YAML.safe_load_file(HYKU)
mine = YAML.safe_load_file(MINE)

h_props = hyku['properties']
m_props = mine['properties']

# Keys worth diffing: the ones that change behavior. Prose and provenance keys
# are expected to differ and would drown the signal.
COMPARED = %w[range data_type indexing form view property_uri cardinality requirement].freeze

def norm(value)
  case value
  when Array then value.sort
  when Hash  then value.sort.to_h
  else value
  end
end

# The two profiles declare different classes, so comparing `available_on` lists
# directly would flag every property. What is comparable is the shape: whether a
# property is scoped to the file set, the work types, or both.
def scope_shape(config)
  classes = Array(config.dig('available_on', 'class'))
  return 'none' if classes.empty?

  file_set = classes.include?('Hyrax::FileSet')
  others = classes.reject { |c| c == 'Hyrax::FileSet' }.any?
  return 'file set only' if file_set && !others
  return 'work types only' if others && !file_set

  'file set + others'
end

missing = []
differing = {}
identical = []

h_props.each do |name, h|
  m = m_props[name]
  if m.nil?
    missing << name
    next
  end

  diffs = COMPARED.filter_map do |key|
    hv = norm(h[key])
    mv = norm(m[key])
    next if hv == mv

    [key, hv, mv]
  end

  h_shape = scope_shape(h)
  m_shape = scope_shape(m)
  diffs << ['available_on (shape)', h_shape, m_shape] if h_shape != m_shape

  diffs.empty? ? identical << name : differing[name] = diffs
end

puts "Hyku declares #{h_props.size} properties; the migrated profile has #{m_props.size}."
puts
puts "ABSENT from the migrated profile (#{missing.size}):"
missing.each { |n| puts "  #{n}" }
puts
puts "IDENTICAL on every compared key (#{identical.size}):"
identical.each_slice(5) { |s| puts "  #{s.join(', ')}" }
puts
puts "DIFFERING (#{differing.size}):"
differing.each do |name, diffs|
  puts
  puts "  #{name}"
  diffs.each do |key, hv, mv|
    puts "    #{key}:"
    puts "      hyku: #{hv.inspect}"
    puts "      ours: #{mv.inspect}"
  end
end

puts
puts "Properties only in the migrated profile: #{(m_props.keys - h_props.keys).size}"
