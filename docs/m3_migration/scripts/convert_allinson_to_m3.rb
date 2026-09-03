#!/usr/bin/env ruby
# frozen_string_literal: true

# Converts an Allinson Flex profile into a Hyrax M3 flexible metadata profile.
#
#   ruby scripts/convert_allinson_to_m3.rb [source.yml] [target.yaml]
#
# Both arguments are optional and default to the profiles in ../files, resolved
# from this script's own location so it runs from any working directory.
#
# The two formats share a skeleton but differ on `indexing:`, which Allinson
# Flex treats as behavioral hints and Hyrax M3 treats as literal Solr field
# names. See ../documentation/allinson_flex_to_m3_migration.md for the full
# mapping and the reasoning behind each transform.

require 'yaml'
require 'json'

FILES_DIR = File.expand_path('../files', __dir__)

SOURCE = ARGV[0] || File.join(FILES_DIR, 'utk_allinson_profile.yml')
TARGET = ARGV[1] || File.join(FILES_DIR, 'migrated_profile.yaml')

raise(ArgumentError, "source profile not found: #{SOURCE}") unless File.exist?(SOURCE)

# Classes Hyrax requires in every profile, from Hyrax.config.{admin_set,collection,file_set}_model.
REQUIRED_CLASSES = {
  'AdminSetResource' => 'Admin Set',
  'CollectionResource' => 'Collection',
  'Hyrax::FileSet' => 'File Set'
}.freeze

# UTK's Attachment work type is dropped; these 15 Attachment-only technical
# properties move to the FileSet, where file-level metadata belongs in Hyrax.
FILE_SET_PROPERTIES = %w[
  behavior bits_per_sample capture_software color_profile color_space
  compression_scheme file_language file_size format_name frame_height
  frame_width hash_value is_associated_with_page rdf_type xresolution
].freeze

FILE_SET_CLASS = 'Hyrax::FileSet'
ATTACHMENT_CLASS = 'Attachment'

# Work types UTK is not carrying forward. Removing a class drops it from
# `classes` and from every `available_on.class` list; a property scoped only to
# a dropped class would be left orphaned, so the script fails rather than
# silently discarding it.
DROPPED_CLASSES = [ATTACHMENT_CLASS, 'GenericWork'].freeze

# Work types being renamed, old name => new name. Applied to `classes` and to
# every `available_on.class` reference. Renaming rather than dropping keeps the
# properties scoped to the class, so nothing is orphaned.
RENAMED_CLASSES = {
  'Image' => 'StillImage'
}.freeze

def rename_class(name)
  RENAMED_CLASSES.fetch(name, name)
end

# A display_label that merely echoed the old class name would otherwise keep
# showing it in the UI under the new key. One that was set to something else is
# a deliberate label and is left alone.
def rename_class_config(old_name, config)
  return config unless RENAMED_CLASSES.key?(old_name)
  return config unless config['display_label'] == old_name

  config.merge('display_label' => RENAMED_CLASSES[old_name])
end

# Solr suffixes: _tesim is stored+indexed multi-valued text, _sim is the
# string form used for faceting and display. Convention copied from
# hyku/config/metadata_profiles/m3_profile.yaml.
#
# The source's `stored_searchable` flag is dropped rather than carried over.
# It is schema-valid, but FlexibleCatalogBehavior#stored_searchable? treats it
# as equivalent to declaring `<name>_tesim`, which every property here already
# has, so it never changes behavior. Hyku's profile uses it zero times in 80
# properties for the same reason.
def index_keys_for(name, source_indexing)
  keys = ["#{name}_tesim"]
  keys.unshift("#{name}_sim") if source_indexing.include?('displayable') || source_indexing.include?('facetable')
  keys << 'facetable' if source_indexing.include?('facetable')
  keys << 'admin_only' if source_indexing.include?('admin_only')
  keys << 'editor_only' if source_indexing.include?('editor_only')
  keys
end

# Hyrax reads data_type first in FlexibleSchema#determine_multiplicity, so
# normalizing onto it makes multiplicity unambiguous regardless of what the
# source said via multi_value or cardinality.
def data_type_for(config)
  return 'array' if config['multi_value'] == true
  return 'string' if config['multi_value'] == false

  max = config.dig('cardinality', 'maximum')
  max.nil? || max.to_i > 1 ? 'array' : 'string'
end

# Hyrax::SchemaLoader#type_for constantizes Valkyrie::Types::<local name> and
# raises ArgumentError when that constant is missing, so a range must name a
# concrete datatype. rdf-schema#Literal is valid RDF but carries none, and
# Allinson Flex uses it for identifier fields; it has no Valkyrie::Types::Literal
# and raises when the deposit form builds its attributes. Neither the JSON
# schema nor FlexibleSchemaValidatorService resolves ranges, so this is caught
# here or not at all.
UNMAPPABLE_RANGES = {
  'http://www.w3.org/2000/01/rdf-schema#Literal' => 'http://www.w3.org/2001/XMLSchema#string'
}.freeze

def normalize_range(value)
  UNMAPPABLE_RANGES.fetch(value, value)
end

# display_label.default is passed through I18n.t by
# Hyrax::FlexibleCatalogBehavior#display_label_for, so a Blacklight key there
# localizes the label while a literal string cannot. Only keys that actually
# resolve are worth setting: an unresolved key renders as its own raw text.
# Verified against the app's i18n table, `show` unless noted.
BLACKLIGHT_LABEL_SCOPES = {
  'title' => 'show', 'alternative_title' => 'index', 'creator' => 'show',
  'contributor' => 'show', 'date_created' => 'show', 'subject' => 'show',
  'language' => 'show', 'extent' => 'show', 'resource_type' => 'index',
  'publisher' => 'show', 'rights_statement' => 'index', 'keyword' => 'show',
  'license' => 'index', 'table_of_contents' => 'index'
}.freeze

def blacklight_label_for(name)
  scope = BLACKLIGHT_LABEL_SCOPES[name]
  return nil unless scope

  "blacklight.search.fields.#{scope}.#{name}_tesim"
end

# A property with no `form:` block never reaches a form. Hyrax's
# ResourceForm#initialize registers fields from `form_definitions_for`, which
# skips properties whose form options are empty, so the `display: true` default
# it applies never gets the chance to run. `primary_terms` and `secondary_terms`
# then both miss the field and it renders nowhere.
#
# Some properties are meant to stay off the form: they are autopopulated on
# ingest and must never be user-editable. UTK records that in the definition
# prose rather than in a key, so that sentence is the signal.
FORM_EXCLUSION_PATTERN = /should not appear in metadata form/i

# Properties whose definition carries that sentence but which UTK wants on the
# form anyway, editable and unremarkable. Listed explicitly so the prose stays
# as written in the source profile.
FORM_EXCLUSION_OVERRIDES = %w[ark is_part_of resource_link].freeze

# System-managed core properties Hyrax writes itself. Hyku's own profile leaves
# these three without a form block, which is the convention followed here.
SYSTEM_MANAGED = %w[date_modified date_uploaded depositor].freeze

def excluded_from_form?(name, config)
  return true if SYSTEM_MANAGED.include?(name)
  return false if FORM_EXCLUSION_OVERRIDES.include?(name)

  config.dig('definition', 'default').to_s.match?(FORM_EXCLUSION_PATTERN)
end

# Requiredness has two signals in the source and they disagree once
# (primary_identifier). Either one marks the field required, matching
# M3AttributeDefinition#cardinality_required?, which reads cardinality.minimum.
def required_in_source?(config)
  config['requirement'] == 'required' || config.dig('cardinality', 'minimum').to_i >= 1
end

# Required fields lead the form; everything else falls below the fold, which
# `display` (defaulted to true by Hyrax) is enough to reach.
def form_options_for(name, config)
  return nil if excluded_from_form?(name, config)

  required_in_source?(config) ? { 'required' => true, 'primary' => true } : { 'display' => true }
end

# The exported Allinson Flex profile is tab-indented, which YAML forbids, so
# Psych rejects it before any of the transforms below run. Indentation is a
# uniform 4 tabs per nesting level and no value contains a tab, so rewriting
# them to spaces in memory is lossless and leaves the source file untouched.
TABS_PER_LEVEL = 4

def detab(text)
  text.gsub(/^\t+/) { |tabs| '  ' * (tabs.length / TABS_PER_LEVEL) }
end

raw = File.read(SOURCE)
raw = detab(raw) if raw.match?(/^\t/)
source = YAML.safe_load(raw)
properties = source['properties']

# --- classes -------------------------------------------------------------
# Add the three Hyrax requires, drop the classes UTK is not carrying forward
# (Attachment in favor of Hyrax::FileSet), and apply renames.
classes = {}
REQUIRED_CLASSES.each { |name, label| classes[name] = { 'display_label' => label } }
source['classes'].each do |name, config|
  next if DROPPED_CLASSES.include?(name)

  classes[rename_class(name)] = rename_class_config(name, config)
end

missing_renames = RENAMED_CLASSES.keys - source['classes'].keys
unless missing_renames.empty?
  warn "WARNING: RENAMED_CLASSES names absent from the source profile: #{missing_renames.join(', ')}"
end

all_classes = classes.keys
work_classes = all_classes - [FILE_SET_CLASS]

# --- properties ----------------------------------------------------------
converted = {}
report = { contradictory_multiplicity: [], moved_to_file_set: [], dropped_attachment: 0,
           normalized_ranges: [], blacklight_labels: [], renamed_scope: [],
           form_required: [], form_excluded: [] }

properties.each do |name, config|
  new_config = config.dup
  source_indexing = Array(config['indexing'])

  # available_on.class: drop removed classes, apply renames, and re-scope
  # technical properties to the FileSet.
  klasses = Array(config.dig('available_on', 'class')).uniq
  if FILE_SET_PROPERTIES.include?(name)
    klasses = [FILE_SET_CLASS]
    report[:moved_to_file_set] << name
  else
    report[:dropped_attachment] += 1 if klasses.include?(ATTACHMENT_CLASS)
    report[:renamed_scope] << name if klasses.any? { |k| RENAMED_CLASSES.key?(k) }
    kept = klasses - DROPPED_CLASSES
    if kept.empty? && klasses.any?
      raise "#{name} is scoped only to dropped classes (#{klasses.join(', ')}); " \
            'move it to another class or remove the property before converting.'
    end
    klasses = kept.map { |k| rename_class(k) }.uniq
  end
  new_config['available_on'] = config['available_on'].merge('class' => klasses)

  # indexing: replace behavioral hints with real Solr field names.
  new_config['indexing'] = index_keys_for(name, source_indexing)

  # multiplicity: normalize onto data_type.
  new_config['data_type'] = data_type_for(config)

  # range: replace values that have no Valkyrie type. controlled_values.format
  # is not read for typing, but is kept in step so the two never disagree.
  if UNMAPPABLE_RANGES.key?(config['range'])
    report[:normalized_ranges] << name
    new_config['range'] = normalize_range(config['range'])
  end
  if (format = config.dig('controlled_values', 'format')) && UNMAPPABLE_RANGES.key?(format)
    new_config['controlled_values'] = config['controlled_values'].merge('format' => normalize_range(format))
  end

  # display_label: prefer a Blacklight i18n key so the label localizes.
  if (key = blacklight_label_for(name))
    report[:blacklight_labels] << name
    new_config['display_label'] = { 'default' => key }
  end

  # form: without one the property is never registered as a form field.
  if (form = form_options_for(name, config))
    new_config['form'] = form
    report[:form_required] << name if form['required']
  else
    report[:form_excluded] << name
  end

  # A multi_value/cardinality.maximum contradiction resolves toward
  # multi-valued (matching Hyrax), so the now-false maximum is removed rather
  # than left contradicting data_type.
  if config['multi_value'] == true && config.dig('cardinality', 'maximum') == 1
    report[:contradictory_multiplicity] << name
    new_config['cardinality'] = config['cardinality'].reject { |k, _| k == 'maximum' }
    new_config.delete('cardinality') if new_config['cardinality'].empty?
  end
  new_config.delete('multi_value')

  # Show-page rendering is opt-in via `view:` in Hyrax; without this every
  # field would silently vanish from show pages. Restricted fields are not
  # rendered in the attribute table, so they get no view block.
  unless source_indexing.include?('admin_only') || source_indexing.include?('editor_only')
    new_config['view'] = { 'html_dl' => true }
  end

  converted[name] = new_config
end

# --- core metadata -------------------------------------------------------
# Hyrax's CoreMetadataValidator requires these on EVERY class in the profile,
# with exact predicates and index keys from hyrax config/metadata/core_metadata.yaml.
def core_property(display, predicate, range, data_type, indexing, classes, extra = {})
  {
    'available_on' => { 'class' => classes },
    'data_type' => data_type,
    'display_label' => { 'default' => display },
    'property_uri' => predicate,
    'range' => range
  }.merge(indexing.empty? ? {} : { 'indexing' => indexing }).merge(extra)
end

XSD_STRING = 'http://www.w3.org/2001/XMLSchema#string'
XSD_DATETIME = 'http://www.w3.org/2001/XMLSchema#dateTime'

SINGLE = { 'minimum' => 0, 'maximum' => 1 }.freeze

# date_modified and date_uploaded carry no `indexing:` — Hyrax indexes them
# itself, and core_metadata.yaml declares no index_keys for either. Their
# display_labels are Blacklight i18n keys so the label localizes, matching
# hyku/config/metadata_profiles/m3_profile.yaml.
converted['date_modified'] ||= core_property(
  'blacklight.search.fields.show.date_modified_dtsi',
  'http://purl.org/dc/terms/modified', XSD_DATETIME, 'string', [], all_classes,
  'cardinality' => SINGLE.dup, 'view' => { 'html_dl' => true }
)

converted['date_uploaded'] ||= core_property(
  'blacklight.search.fields.show.date_uploaded_dtsi',
  'http://purl.org/dc/terms/dateSubmitted', XSD_DATETIME, 'string', [], all_classes,
  'cardinality' => SINGLE.dup
)

converted['depositor'] ||= core_property(
  'Depositor', 'http://id.loc.gov/vocabulary/relators/dpt', XSD_STRING,
  'string', %w[depositor_tesim depositor_ssim], all_classes,
  'cardinality' => SINGLE.dup, 'index_documentation' => 'searchable'
)

converted['label'] ||= core_property(
  'Label', 'info:fedora/fedora-system:def/model#downloadFilename', XSD_STRING,
  'array', %w[label_sim label_tesim], all_classes,
  'cardinality' => SINGLE.dup,
  'index_documentation' => 'displayable, searchable',
  'form' => { 'primary' => false },
  'view' => { 'html_dl' => true }
)

# title/creator already exist in the source but need core-metadata conformance.
converted['title']['indexing'] = %w[title_sim title_tesim]
converted['title']['data_type'] = 'array'
converted['title']['cardinality'] = { 'minimum' => 1 }
converted['title']['form'] = { 'required' => true, 'primary' => true }

converted['creator']['indexing'] = %w[creator_sim creator_tesim facetable]
converted['creator']['data_type'] = 'array'
converted['creator']['property_uri'] = 'http://purl.org/dc/elements/1.1/creator'

converted['keyword']['data_type'] = 'array' if converted['keyword']

# CoreMetadataValidator#validate_property_available_on requires these on every
# class in the profile. The list is core_metadata.yaml's, plus creator, which
# the validator injects separately.
%w[title date_modified date_uploaded depositor creator].each do |name|
  converted[name]['available_on'] = (converted[name]['available_on'] || {}).merge('class' => all_classes)
end

# `label` is governed by validate_label_prop instead, which only requires that
# available_on include the file set model. It holds a download filename, so the
# work types have no use for it.
converted['label']['available_on'] = { 'class' => [FILE_SET_CLASS] }

# Key order carries no meaning to Hyrax, but the file is read and diffed by
# people: keys the transforms add would otherwise trail in insertion order and
# sit in a different place in every property. `name` leads because it aliases
# the attribute several entries resolve to, so it identifies what follows.
LEADING_KEYS = %w[name].freeze

def order_keys(config)
  leading = LEADING_KEYS & config.keys
  (leading + (config.keys - leading).sort).to_h { |k| [k, config[k]] }
end

converted = converted.transform_values { |config| order_keys(config) }

# --- assemble ------------------------------------------------------------
target = {
  'm3_version' => source['m3_version'],
  'profile' => {
    'date_modified' => Time.now.strftime('%Y-%m-%d'),
    'responsibility' => source['profile']['responsibility'],
    'responsibility_statement' => source['profile']['responsibility_statement'],
    'type' => 'Migrated from AllinsonFlex profile',
    'version' => 1
  },
  'classes' => classes,
  'contexts' => source['contexts'],
  'mappings' => source['mappings'],
  'properties' => converted
}

# Psych emits YAML anchors/aliases (&1 / *1) when the same object is reachable
# from several places, and Hyrax loads profiles with YAML.safe_load_file, which
# rejects aliases outright. Round-tripping through JSON breaks the shared object
# identity so every value is written literally.
File.write(TARGET, JSON.parse(JSON.generate(target)).to_yaml)

puts "Wrote #{TARGET}"
puts "  properties:        #{converted.size} (source #{properties.size})"
puts "  classes:           #{classes.size} (source #{source['classes'].size})"
puts "  moved to FileSet:  #{report[:moved_to_file_set].size}"
puts "  Attachment scope removed from: #{report[:dropped_attachment]} properties"
puts "  contradictory multi_value/cardinality resolved: #{report[:contradictory_multiplicity].size}"
puts "  unmappable ranges normalized: #{report[:normalized_ranges].size}"
puts "  Blacklight display labels applied: #{report[:blacklight_labels].size}"
puts "  classes dropped:   #{DROPPED_CLASSES.join(', ')}"
puts "  classes renamed:   #{RENAMED_CLASSES.map { |o, n| "#{o} -> #{n}" }.join(', ')}"
puts "  properties rescoped by rename: #{report[:renamed_scope].size}"
puts
puts "Contradictory multiplicity properties (review with UTK):"
report[:contradictory_multiplicity].each_slice(6) { |s| puts "  #{s.join(', ')}" }

unless report[:normalized_ranges].empty?
  puts
  puts "Ranges normalized to xsd:string (confirm each is not numeric or a date):"
  report[:normalized_ranges].each_slice(6) { |s| puts "  #{s.join(', ')}" }
end

unless report[:form_required].empty?
  puts
  puts "form: {required: true, primary: true} (from requirement: or cardinality.minimum):"
  report[:form_required].each_slice(6) { |s| puts "  #{s.join(', ')}" }
end

unless report[:form_excluded].empty?
  puts
  puts "NO form: block, so these never render on a metadata form:"
  report[:form_excluded].each do |n|
    reason = SYSTEM_MANAGED.include?(n) ? 'system-managed' : 'definition says it should not appear'
    puts "  #{n} (#{reason})"
  end
end
