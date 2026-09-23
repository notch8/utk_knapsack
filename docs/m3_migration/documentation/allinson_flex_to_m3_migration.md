# Migrating an Allinson Flex profile to a Hyrax M3 profile

Hyrax v5.3+ replaced the Allinson Flex gem with built-in *flexible metadata*
(`HYRAX_FLEXIBLE=true`). Profiles are stored in the `hyrax_flexible_schemas`
table and validated by `Hyrax::FlexibleSchemaValidatorService`.

The two formats share a skeleton — `m3_version`, `profile`, `classes`,
`contexts`, `mappings`, `properties` — and both declare `m3_version: 1.0.beta2`.
That similarity is the main hazard: an Allinson Flex profile parses as valid
YAML, reads correctly to a human, and still fails validation.

The largest difference is `indexing:`. Allinson Flex used it for *behavioral
hints* (`displayable`, `stored_searchable`). Hyrax M3 uses it for **literal Solr
field names**. A profile whose `indexing:` says `displayable` declares a Solr
field that does not exist.

**Worked example.** Converting UTK's profile (v54, 191 properties, 9 classes)
produced **378 JSON-schema errors**, every one from `displayable` appearing in
`indexing:` on 189 of 191 properties. Only two properties validated as written.

`indexing:` is the loudest difference, not the only one. The rest surface later
and more quietly: a `range` with no Valkyrie type raises when a work type builds
its attributes, and a literal `display_label` is valid but never localizes.
Both are covered below, and both pass every validator.

The end state for UTK is 195 properties across 10 classes, produced by
`scripts/convert_allinson_to_m3.rb`. Re-run the script rather than
editing its output by hand, so the next profile version starts from the same
transforms.

## Authoritative sources

Verified against `samvera/hyrax` @ `ca9ccf8`. The profile contract lives in code,
not documentation — when in doubt, read these:

| Concern | File |
|---|---|
| Formal JSON schema | `config/metadata_profiles/m3_json_schema.json` |
| Validator orchestration | `app/services/hyrax/flexible_schema_validator_service.rb` |
| Individual validators | `app/services/hyrax/flexible_schema_validators/` |
| Key translation / parsing | `app/models/hyrax/flexible_schema.rb` |
| Schema loading | `app/services/hyrax/m3_schema_loader.rb` |
| Required core properties | `config/metadata/core_metadata.yaml` |
| Feature documentation | `documentation/flexible_metadata.md` |

A known-good reference profile: `hyku/config/metadata_profiles/m3_profile.yaml`.
Copy its conventions rather than inventing them.

---

## Field-by-field key mapping

| Allinson Flex | M3 / Hyrax outcome | Notes |
|---|---|---|
| `indexing: [displayable]` | **Remove** | No M3 equivalent. Record the intent in `index_documentation` free text. |
| `indexing: [stored_searchable]` | Keep | Legal enum flag. |
| `indexing: [facetable]` | Keep | Legal enum flag. |
| `indexing: [admin_only]` | Keep | Legal; also hides the field from the catalog entirely. |
| *(absent)* | `indexing: [<name>_sim, <name>_tesim]` | **Must be added.** Real Solr keys; nothing else produces them. |
| `multi_value: true/false` | `data_type: array/string` | Legacy key is still read, but `data_type` is checked first. |
| `cardinality.minimum` | Required flag | `>= 1` ⇒ required, via `M3AttributeDefinition#cardinality_required?`. |
| `cardinality.maximum` | Multiplicity fallback | Consulted only when `data_type` and `multi_value` are both absent. |
| `range` | `type` (Dry type) | Mapped by `lookup_type`: `#anyURI`→`uri`, `#dateTime`→`date_time`, else the local name underscored. The fallback must resolve to a real `Valkyrie::Types::*` constant, so only concrete XSD ranges survive it. See [Ranges that do not resolve](#ranges-that-do-not-resolve). |
| `property_uri` | `predicate` | Renamed by `values_map`. |
| `display_label` (literal) | `display_label.default` | Passed through `I18n.t`, so a Blacklight key here localizes and a literal cannot. See [Display labels](#display-labels). |
| `available_on.class` | Class scope | Must name registered curation concerns. |
| `available_on.context` | `context` | Filtered by `M3SchemaLoader#contextual_attributes`. |
| `definition`, `usage_guidelines`, `sample_values`, `index_documentation`, `syntax`, `validations`, `requirement`, `controlled_values`, `mappings` | Passed through | Legal and preserved; per-property blocks are not strict. |
| *(absent)* | `form: {primary, display, required, input_type}` | **Required to reach the deposit form at all.** A property with no `form:` block is never registered as a form field. See [A property without `form:` renders nowhere](#a-property-without-form-renders-nowhere). |
| *(absent)* | `view: {html_dl, render_as, position}` | **Required for show-page rendering.** |
| *(absent)* | `name:` alias | Lets several entries resolve to one attribute across contexts. |
| *(absent)* | `available_on.properties` | Marks a compound subproperty. |

### Keys that are strict, and keys that are not

A frequent misreading of the JSON schema: the `properties.*` subschema lists
allowed keys but does **not** set `additionalProperties: false`. Extra keys are
therefore legal, and Hyrax reads several of them. Do not strip
`controlled_values`, `mappings`, or `sample_values` to "conform".

The `profile:` block *is* strict (`additionalProperties: false`). Only
`date_modified`, `responsibility`, `responsibility_statement`, `type`, and
`version` are permitted; `responsibility` and `date_modified` are required.

### Key order within a property

YAML mappings are unordered, so key order is invisible to Hyrax and free to
choose. It is not invisible to reviewers, which is the reason to fix it: keys the
conversion adds (`data_type`, `view`, `form`) otherwise trail in insertion order,
landing somewhere different in every property, and hand-built core properties
come out in whatever order they were written. The result is a diff where a real
change is hard to spot.

The convention, applied by `order_keys` as the last step before assembly:

1. `name` first when present (`LEADING_KEYS`). It aliases the attribute that
   several entries resolve to, so it identifies what the rest of the block
   describes.
2. Everything else alphabetical.

The source profile happens to arrive alphabetical already, so before this pass
zero of 195 properties were ordered and after it all 195 are. No UTK property
currently declares `name`; the rule is there for the ones that will.

---

## Decision points

### 1. Class naming — Valkyrie vs ActiveFedora

`ClassValidator` requires every class (beyond the three required ones) to be a
registered curation concern, and compares it to
`Valkyrie.config.resource_class_resolver`. A mismatch yields:

> Mismatched Valkyrie classes found: 'Image' should be 'ImageResource'.

Flexible metadata is **Valkyrie-only**. An ActiveFedora app cannot load a
flexible profile regardless of how the profile is written.

- Keep ActiveFedora names ⇒ profile is structurally valid but will not load
  until models migrate. Reasonable when the Valkyrie migration is separately
  planned and you want the profile ready.
- Use `...Resource` names ⇒ loads on a migrated app; misleading before then.

Either way the Valkyrie model migration is a prerequisite, not an optional
follow-up. Decide deliberately and write the decision down.

UTK resolved this by naming classes for the registered curation concerns
(`StillImage`, `Audio`, `Book`, …) rather than keeping the source's names, which
is what the rename step below is for.

### 2. Renaming and removing classes

A source profile's work types rarely match the ones the application registers,
so the conversion carries two declarative maps. Both are applied to `classes`
*and* to every `available_on.class` list, which is the part that is easy to do
by hand and get half-right:

| Constant | Effect |
|---|---|
| `RENAMED_CLASSES` | `Image` ⇒ `StillImage`. Properties stay scoped to the class under its new name. |
| `DROPPED_CLASSES` | `Attachment`, `GenericWork`. Removed from `classes` and from every property scope. |

Renaming also updates the class's own `display_label` when the label merely
echoed the old class name; a label deliberately set to something else is left
alone. Without that, the UI keeps showing "Image" under the key `StillImage`.

**Dropping a class can orphan properties.** A property scoped only to a dropped
class ends up with an empty `available_on.class`, which is a silently broken
property rather than a validation error. The script raises instead:

```
utk_cartographer is scoped only to dropped classes (GenericWork); move it to
another class or remove the property before converting.
```

Check the exclusive scopes before adding a class to `DROPPED_CLASSES`:

```ruby
props.select { |_, c| Array(c.dig('available_on', 'class')) == ['GenericWork'] }.keys
```

For UTK, `GenericWork` had none, so its removal dropped no properties, while
`Image` had one (`utk_cartographer`) that the rename carried across safely.

### 3. Required classes

Every profile must declare `Hyrax.config.admin_set_model`, `collection_model`,
and `file_set_model`. In Hyku these are `AdminSetResource`,
`CollectionResource`, and `Hyrax::FileSet`. Allinson Flex profiles typically
declare only work types, so all three are usually missing.

This has a knock-on effect: core properties must be available on *every* class
in the profile, so adding three classes edits `available_on` on every core
property.

### 4. FileSet-level metadata

Hyrax expects file-level technical metadata (checksums, dimensions, format) on
the FileSet, and requires a `label` property available on `file_set_model`.
Allinson Flex profiles often model this as a work type instead.

Re-scoping such properties to `Hyrax::FileSet` is a **data-model change, not a
profile change**: existing records hold that metadata at the work level and need
migration. Confirm with the metadata owners before shipping; do not treat it as
a mechanical edit.

### 5. Core metadata conformance

`CoreMetadataValidator` enforces `title`, `date_modified`, `date_uploaded`,
`depositor`, and `creator` (injected even when absent from the YAML). Each must
exist, be on every class, and match the exact `predicate` and `index_keys` in
`core_metadata.yaml`.

**`label` is not one of them**, despite also being required. It is governed by
`validate_label_prop`, a separate check with a weaker rule: the property must
exist, and its `available_on.class` must *include* `Hyrax.config.file_set_model`.
Nothing requires it on the work types. Since `label` holds a download filename,
scoping it to `Hyrax::FileSet` alone is both valid and more honest than
listing every class. Hyku's profile does list work types there, so following the
reference blindly is what puts `label` everywhere.

`creator` is the usual conflict. Hyrax demands
`http://purl.org/dc/elements/1.1/creator`, while many profiles use a MARC
relator such as `http://id.loc.gov/vocabulary/relators/cre`. Satisfying the
validator **changes an existing predicate**, which affects indexing, OAI-PMH
output, and any downstream consumer. If the relator must be preserved, keep it
as a separately-keyed property and let `creator` take the DC predicate. This is
a metadata-governance decision, not a technical one.

Copy the shape of these five from a working profile rather than inventing it —
`hyku/config/metadata_profiles/m3_profile.yaml` is the reference. Details that
are easy to get wrong:

- `date_modified` and `date_uploaded` carry **no `indexing:` key at all**.
  `core_metadata.yaml` declares no `index_keys` for either, and Hyrax indexes
  them itself. An empty array works, but omitting the key matches convention.
- Their `display_label.default` is a **Blacklight i18n key**
  (`blacklight.search.fields.show.date_modified_dtsi`), not a literal string —
  that is what makes the label localize.
- `date_modified` declares `view: {html_dl: true}`; `date_uploaded` does not.
  Modified date shows on the show page, upload date does not.
- `depositor` orders its keys `depositor_tesim, depositor_ssim`, and is
  `data_type: string` with `cardinality: {minimum: 0, maximum: 1}`.
- `label` is `data_type: array` with `form: {primary: false}`.

### 6. Multiplicity contradictions

Profiles commonly declare `multi_value: true` alongside `cardinality.maximum: 1`.
Hyrax's `determine_multiplicity` checks `data_type`, then `multi_value`, then
cardinality — so such a field is multi-valued, and the `maximum: 1` is inert.

Normalize onto `data_type` and drop the contradicted `maximum`. Preserving
current behavior means `data_type: array`, but some fields are semantically
single-valued (an EXIF resolution, a checksum) and were only ever multi-valued
by accident. Surface the list for review rather than silently freezing it.

### 7. Show-page visibility

Show-page rendering is **opt-in**: a property renders only when it declares a
meaningful `view:` block, such as `view: {html_dl: true}`. Allinson Flex
profiles have no `view:` blocks, so a mechanical conversion produces a profile
where **every field disappears from show pages** while still validating and
indexing correctly. This is the most easily missed regression in the migration.

Restricted fields (`admin_only` / `editor_only`) are excluded from the attribute
table anyway and need no `view:` block.

### 8. YAML aliases

If the profile is generated programmatically, Ruby's YAML emitter writes
anchors and aliases (`&1` / `*1`) whenever one object is reachable from several
places — for instance a shared `available_on.class` array. Hyrax loads profiles
with `YAML.safe_load_file`, which **rejects aliases**:

> Psych::BadAlias: Unknown alias: 1

Round-trip through JSON (`JSON.parse(JSON.generate(hash))`) before dumping, so
every value is written literally. A hand-edited profile is unaffected.

---

## Validation error catalog

`Hyrax::FlexibleSchemaValidatorService#validate!` runs these in order. Errors
block the save; warnings do not.

| Validator | Checks | Representative message |
|---|---|---|
| `SchemaValidator` | The JSON schema | ``Schema error at `/properties/x/indexing/0`: Invalid value `"displayable"` for type `pattern`.`` |
| — required classes | admin set, collection, file set present | `Missing required classes: Hyrax::FileSet.` |
| `ClassValidator#validate_availability!` | Classes are registered concerns, Valkyrie-named | `Mismatched Valkyrie classes found: 'Image' should be 'ImageResource'.` / `Invalid classes: Foo.` |
| `ClassValidator#validate_references!` | `available_on.class` ⊆ `classes` | ``Classes referenced in `available_on` but not defined in `classes`: Bar.`` |
| `ExistingRecordsValidator` | No class with existing records removed | Blocks dropping a class still in use |
| — label | `label` exists, on file set model | `A `label` property is required.` / `Label must be available on Hyrax::FileSet.` |
| `CoreMetadataValidator` | Core props exist, typed, indexed, predicated, on all classes | `Missing required property: depositor.` · `Property 'creator' must have data_type set to 'array'.` · `Property 'title' is missing required indexing: title_sim, title_tesim.` · `Property 'x' must be available on all classes, but is missing from: Y.` |
| `SortPropertiesValidator` | Catalog sort fields exist on work types | *warning* |
| `RedirectsValidator` | `redirects` present when the feature is on | error only when config **and** Flipflop are enabled |
| `CompoundValidator` | `subproperties:` well-formed | — |
| `RichTextValidator` | `rich_text` not on controlled vocab | *warning* |
| `SearchResultsTruncateValidator` | `search_results_truncate` implies `render_as: html` | *warning* |

### Indexing rules

Each `indexing:` entry must either match

```
^[a-z_]+_(tesi|tesim|teim|ssi|sim|ssm|bsi|isi|dts|dtsi|ti|si|ss|is|bs|dt|ssim)$
```

or be one of `facetable`, `admin_only`, `editor_only`, `stored_searchable`.
`displayable` satisfies neither, which is why it produces two errors per
occurrence (`pattern` and `enum`).

Convention from Hyku's profile:

- `<name>_tesim` — stored, searchable, multi-valued text. Effectively always.
- `<name>_sim` — string form for faceting and display.
- `facetable` — adds the field to facets.
- `admin_only` / `editor_only` — restrict visibility; also removes the field
  from the catalog entirely.

### Ranges that do not resolve

`range` is converted to a Ruby type by `Hyrax::SchemaLoader#type_for`, which
recognizes the shortcuts `id`, `uri`, `date_time`, `hash` and `linked_record`,
and otherwise constantizes `Valkyrie::Types::<local name classified>`. When that
constant does not exist it raises, and the raise happens at **attribute-build
time**, not at save time:

```
ArgumentError: Unrecognized type: literal
  hyrax app/services/hyrax/schema_loader.rb:248:in `type_for'
  hyrax app/models/concerns/hyrax/flexibility.rb:79:in `load'
```

The visible symptom is that every affected work type 500s on `#new` and `#edit`
for anyone trying to deposit, while the profile itself saved cleanly.

Two ranges show up in practice, and they fail at different moments.

**`rdf-schema#Literal`** fails immediately and loudly. It is valid RDF — the
generic supertype of all literals — but carries no datatype, so there is no
`Valkyrie::Types::Literal` to map it onto. Allinson Flex uses it freely for
identifier-ish fields; Hyrax cannot.

**`XMLSchema#anyURI`** is the dangerous one, because it resolves cleanly and
fails much later, disguised as a Solr problem. `FlexibleSchema#lookup_type` maps
it to `'uri'`, producing a `Valkyrie::Types::URI` attribute whose value is an
`RDF::URI` rather than a String. `RDF::URI#as_json` returns `{"@id" => "..."}`,
and Solr reads a nested object inside an update document as an atomic-update
command:

```
Error: [doc=...] Unknown operation for the an atomic update: @id
```

So **saving a work with any populated `anyURI` field 500s**. The profile
validates, the schema seeds, the form renders and accepts input, and the failure
lands on save with a message that points at Solr rather than at the profile. It
is not a `schema.xml` or field-type problem: the value is malformed before it
leaves Rails.

This affected 77 of UTK's 195 properties — every controlled-vocabulary and
relator field. Only `rights_statement` and `has_work_type` surfaced in testing
because they are the only two required fields; filling in any of the other 75
reproduces it.

Neither stock profile uses `anyURI` at all (Hyrax 0 occurrences, Hyku 0), and
Hyku ranges its `rights_statement` — the *same* `rights_statements` controlled
vocabulary UTK uses — as `string`. That is the precedent worth internalizing:
**`range` only drives the Ruby coercion type, and `controlled_values` is what
names the authority.** Ranging a controlled field as `string` loses nothing.

Both map to `#string` via `UNMAPPABLE_RANGES`. For the `anyURI` fields that is
the whole story, since a URI *is* a string as far as storage is concerned. For
the `Literal` fields, pick the concrete range matching the real content, which
for identifiers is `#string` rather than a numeric type:

| Field | Why `#string`, not `#integer` |
|---|---|
| `isbn` | Leading zeros and the ISBN-10 `X` check digit. |
| `issn` | Hyphenated; the property's own `match_regex` proves it. |
| `oclc` | Identifier, not a quantity; indexes as `_tesim`. |
| `is_associated_with_page` | Page designators include `iv`, `12a`, `cover`. |

Keep `controlled_values.format` in step with `range`. Hyrax does not read
`format` for typing, so a stale one causes no error — but a property whose two
declarations disagree is a trap for the next reader.

**Neither validator catches this.** The JSON schema types `range` as a plain
string, and `FlexibleSchemaValidatorService` never resolves it, so a profile
carrying `#Literal` passes both gates in the migration procedure below and fails
only when a user opens the deposit form. Grep for it directly:

```bash
grep -nE 'rdf-schema#Literal|XMLSchema#anyURI' config/metadata_profiles/m3_profile.yaml
```

`convert_allinson_to_m3.rb` normalizes these via `UNMAPPABLE_RANGES` and reports
what it changed, so a fresh conversion no longer reintroduces them. The report
line is worth reading rather than skipping: it lists the properties it coerced
to `xsd:string`, and a genuinely numeric or date-valued field would be the wrong
thing to coerce.

### Display labels

`display_label` resolves in `Hyrax::FlexibleCatalogBehavior#display_label_for`:

```ruby
label = display_label[I18n.locale] || display_label[:default]
I18n.t(label, default: label)
```

Two consequences follow, and both are easy to get backwards:

- **`default:` is the fallback for every locale**, not an English-only value.
  Because it is passed through `I18n.t` with itself as the fallback, a
  translation key placed there resolves when it exists and renders as its own
  raw text when it does not.
- **The key must live in `default:`.** The only other keys consulted are locale
  codes. Putting a Blacklight key under `en:` makes English render the key while
  every other locale gets the literal.

So a localizable label is a Blacklight key in `default:`. Any per-locale literal
above it is an override, not the mechanism, and is unnecessary unless a locale
should differ from the translation.

Only keys that actually resolve are worth setting, which is a smaller set than
it looks: Blacklight ships entries for Hyrax's standard fields, not for custom
ones. UTK's profile has 14 such properties out of 195, listed in
`BLACKLIGHT_LABEL_SCOPES` in the conversion script; the rest keep literals.
Verify a key resolves before adding it:

```ruby
I18n.exists?('blacklight.search.fields.show.subject_tesim')
```

Note the scope segment is not uniform: most core fields are under `show`, while
`alternative_title`, `resource_type`, `rights_statement`, `license` and
`table_of_contents` are under `index`. There is no rule to infer it from; check
each one.

Two labels change wording when converted, which is the point but is still worth
telling the metadata owners: `rights_statement` "Rights" becomes "Rights
Statement", and `table_of_contents` picks up Blacklight's "Table Of Contents"
capitalization.

### A property without `form:` renders nowhere

This is the one that silently loses most of a profile. Allinson Flex has no
`form` concept, so a mechanical conversion produces properties with no `form:`
block, and those properties never reach a metadata form at all.

The reason is not the obvious one. `form_options` does default to `{}`, and
`ResourceForm#initialize` does default `display` to `true`:

```ruby
current_schema_fields = Hyrax::Schema.m3_schema_loader.form_definitions_for(...)
current_schema_fields.each do |field_name, options|
  singleton_class.property field_name.to_sym, options.merge(display: options.fetch(:display, true), default: [])
end
```

But `form_definitions_for` skips any property whose form options are empty:

```ruby
definitions(schema, version, contexts).each_with_object({}) do |definition, hash|
  next if definition.form_options.empty?
  hash[definition.name] = definition.form_options
end
```

So the field is never registered, and that `display: true` default never gets
the chance to apply. `primary_terms` (selecting `definition[:primary]`) and
`secondary_terms` (selecting `definition[:display] && !definition[:primary]`)
then both miss it. The profile validates, the schema seeds, the work type
instantiates — and the deposit form is nearly empty.

The four keys the form code reads:

| Key | Effect |
|---|---|
| `primary` | Above-the-fold placement. |
| `display` | Below-the-fold placement. Without `primary` or `display`, the field is in neither section. |
| `required` | Marks the field required. |
| `input_type` | Widget override. |

Only two map from an Allinson Flex source; the other two have no equivalent and
should not be invented:

| Form key | Mapped from | Notes |
|---|---|---|
| `required` | `requirement: required` **or** `cardinality.minimum >= 1` | Either signal counts, matching `M3AttributeDefinition#cardinality_required?`, which reads `cardinality.minimum`. The two disagree once in UTK's profile (`primary_identifier`), so taking only `requirement:` would leave the form and Hyrax at odds. |
| `primary` | Required fields | Required fields lead the form. |
| `display` | *(everything else)* | `display: true` for non-required properties, so they land below the fold. |
| `input_type` | *(nothing)* | Allinson Flex has no widget concept. Left unset. |

**Not every property should get one.** Some are autopopulated on ingest and must
never be user-editable. UTK records that in the definition prose rather than in a
key, so the conversion matches the sentence "Should not appear in metadata form"
(`FORM_EXCLUSION_PATTERN`), and the three system-managed core properties
(`date_modified`, `date_uploaded`, `depositor`) are excluded by name
(`SYSTEM_MANAGED`).

The prose is a signal, not a verdict. `ark`, `is_part_of` and `resource_link`
carry that sentence but are wanted on the form, so they sit in
`FORM_EXCLUSION_OVERRIDES`, checked before the pattern. Overriding by name
rather than editing the source profile keeps the definitions as UTK wrote them
and keeps the decision visible in one place. Both come out as
`{ display: true }`: on the form, not required, not primary.

The full list, with reasons, is in
[`form_excluded_properties.md`](form_excluded_properties.md).

For scale: Hyku's own reference profile gives **70 of 80** properties a `form:`
block, and the 10 without are all system-managed. UTK's converted profile lands
at 190 of 195 on the same principle.

### Indexing flags are not Solr fields

`stored_searchable` is legal, despite looking like the behavioral hint the
migration otherwise removes. It appears in the JSON schema's `indexing` enum
alongside `facetable`, `admin_only` and `editor_only`, and
`M3AttributeDefinition#index_keys` filters all four out before treating the rest
as Solr field names:

```ruby
(config.fetch('indexing', nil) || config.fetch('index_keys', []))
  &.reject { |k| ['facetable', 'stored_searchable', 'admin_only', 'editor_only'].include?(k) }
```

`displayable` is the one with no equivalent, which is why it produces two errors
per occurrence and `stored_searchable` produces none.

### Tab-indented source profiles

An Allinson Flex profile exported from the UTK admin UI is **tab-indented**, and
YAML forbids tabs for indentation, so Psych rejects the file before any
conversion happens:

```
Psych::SyntaxError: found character that cannot start any token
  while scanning for the next token at line 4 column 1
```

The error names a character it will not print and points at the first indented
line, which reads as a corrupt file rather than a whitespace convention. The
conversion script detects leading tabs and rewrites them in memory (4 tabs per
nesting level, `TABS_PER_LEVEL`), leaving the source file untouched. Confirm the
depths are a clean multiple before trusting that on a new export:

```bash
grep -oP '^\t+' source.yml | awk '{print length($0)}' | sort -n | uniq -c
grep -cP '\S\t' source.yml   # must be 0: a tab inside a value is data, not indentation
```

---

## Migration procedure

**Convert with a script, not by hand.** At ~200 properties, manual editing is not
reliable, and a script is auditable and rerunnable for the next profile version.
`scripts/convert_allinson_to_m3.rb` does the whole conversion and never writes to
its input. Both paths default to `files/`, resolved from the script's own
location, so it runs from anywhere:

```bash
ruby docs/m3_migration/scripts/convert_allinson_to_m3.rb
```

It reports what it changed. Read that summary rather than skipping to
validation — several of the transforms are judgment calls it made on your behalf.

The transforms it applies, each covered in detail above:

1. **Detab the source** if it is tab-indented, in memory only.
2. **Rewrite `indexing:`** — drop `displayable`, generate `<name>_sim` /
   `<name>_tesim`, retain the enum flags.
3. **Normalize multiplicity** onto `data_type`; drop contradicted `maximum`.
4. **Add required classes**, drop `Attachment`, re-scope technical properties to
   `Hyrax::FileSet`.
5. **Add missing core metadata** (`date_modified`, `date_uploaded`, `depositor`,
   `label`) and conform `title`, `creator`, `keyword`.
6. **Add `view:` blocks** so fields still render.
7. **Fix the `profile:` block** — allowed keys only; quote `date_modified`.
8. **Normalize unmappable `range` values** and keep `controlled_values.format`
   in step.
9. **Apply Blacklight `display_label` keys** to the properties that have one.
10. **Add `form:` blocks** so properties reach the deposit form, excluding the
    ones flagged as autopopulated.
11. **Order the keys** within each property: `name` first, then alphabetical.

Then verify, in this order:

12. **Validate against the JSON schema**, the objective gate:

   ```bash
   cd /path/to/hyrax && ruby -ryaml -rjson_schemer -e '
   schemer = JSONSchemer.schema(Pathname.new("config/metadata_profiles/m3_json_schema.json"))
   errs = schemer.validate(YAML.safe_load_file("m3_profile.yaml")).to_a
   puts errs.empty? ? "VALID" : "#{errs.size} errors"
   errs.first(20).each { |e| puts "  #{e["data_pointer"]}: #{e["data"].inspect} (#{e["type"]})" }'
   ```

13. **Validate in a booted app.** JSON-schema clean is necessary but not
   sufficient — class, core-metadata, and label validators need Rails:

   ```bash
   bundle exec rails r 'p Hyrax::FlexibleSchema.new(
     profile: YAML.safe_load_file("m3_profile.yaml")
   ).tap(&:valid?).errors.full_messages'
   ```

14. **Check the diff, not just validity.** Confirm no property was dropped, no
    per-property key was lost, and every `property_uri` change was intended.

## What validation cannot tell you

A profile can pass every validator and still be wrong:

- **Missing `view:` blocks** — fields validate and index, then vanish from show
  pages.
- **Predicate changes** — retargeting `creator` is structurally fine and
  semantically significant.
- **Class re-scoping** — moving properties between classes validates instantly
  and may strand existing records.
- **Accidental multiplicity** — `data_type: array` on a checksum is legal and
  wrong.
- **Unmappable `range` values** — nothing resolves a range until a work type
  builds its attributes, so the profile saves and the deposit form 500s
  (`rdf-schema#Literal`), or the form works and *saving* 500s with a Solr error
  (`XMLSchema#anyURI`).
- **Unresolved `display_label` keys** — an i18n key that has no translation
  renders as its own raw text on the show page.
- **Missing `form:` blocks** — the profile validates and seeds, the work type
  instantiates, and the deposit form is nearly empty. This is the one that
  silently loses most of a converted profile.

The pattern: both validators check the profile's *shape*, and neither resolves a
value against the application. Each failure surfaces one step further along than
the last — at attribute build, at form render, at save, at display — so no single
checkpoint proves a profile good.

The `anyURI` case is the one to remember when deciding how far to test. Every
earlier checkpoint passes: it validates, it seeds, the work type instantiates,
the form renders and accepts input. It fails only when a populated value is
written, and the error names Solr rather than the profile. **A profile is
verified when a work with its fields filled in saves and comes back**, not when
the form appears.

Treat validation as a floor, and review the semantic diff separately.
