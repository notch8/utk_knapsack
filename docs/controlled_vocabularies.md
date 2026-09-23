# Controlled vocabularies in the migrated profile

74 of the 195 properties declare a `controlled_values.sources` list naming a real
authority. Of the rest, 117 carry the placeholder `sources: ['null']` and 4 have
no `controlled_values` key at all (`date_modified`, `date_uploaded`, `depositor`
and `label`, which the conversion synthesizes rather than reading from the
source). All 121 are free text.

`controlled_values.sources` is what drives the authority behavior. Naming a
vocabulary here is sufficient: the properties backed by a shipped authority
render their picker without any further wiring, and need no `form.input_type`.

The `sources` value must match the authority it refers to. Where an equivalent
already ships with Hyku, the conversion renames the source profile's own
shorthand to the authority's filename (`CONTROLLED_VALUE_SOURCES`), so the two
agree on one identifier:

| Property | Source shorthand | Authority named |
|---|---|---|
| `rights_statement` | `rightsstatements` | `rights_statements` |
| `license` | `creativecommons` | `licenses` |
| `resource_type` | `resourceTypes` | `resource_types` |

Hyku ships eleven authority files in `config/authorities/`. The knapsack has no
such directory of its own yet; `config/initializers/knapsack_authorities.rb`
makes QA search the knapsack's first, so a same-named YAML placed there
overrides Hyku's.

## Ranges are all `xsd:string`

These fields were originally typed `xsd:anyURI`, but **every range in the profile
is now `xsd:string`**. `anyURI` made Hyrax coerce values to `RDF::URI`, whose
`as_json` is `{"@id" => "..."}`, which Solr rejects as a malformed atomic update,
so saving a work with any such field populated failed. Hyku ranges its own
controlled fields as `string` for the same reason.

The change costs nothing: `range` drives only the Ruby coercion type, while
`controlled_values` names the authority. Every vocabulary below survived it
untouched, and Hyku's `rights_statement` is the proof of the pairing — the same
`rights_statements` vocabulary, ranged as `string`.

## Most properties name more than one authority

66 of the 74 combine several authorities in a single `sources` list; only 8 name
one. The groupings are coherent (persons across three name authorities, subjects
across six thesauri, places across a gazetteer plus a name authority), but they
shape how this could ever be implemented.

| Combination | Properties |
|---|---|
| `wikidata`, `naf`, `ulan` | 62 (all agent/role fields) |
| `naf`, `agrovoc`, `fast`, `lcsh`, `tgm`, `wikidata` | `subject` |
| `geonames`, `naf`, `lcsh` | `spatial` |
| `aat`, `lcsh`, `lcgft` | `form` |
| `pcdm`, `pcdmuse`, `pcdmff` | `rdf_type` |
| *(single)* | `language`, `language_local`, `resource_type`, `resource_type_local`, `publication_place`, `rights_statement`, `license`, `has_work_type` |

`naf` appears in four different combinations, more than any other.

Questioning Authority resolves **one** authority per lookup, so a field offering
three sources needs either a federated search across all of them or a
source-picker in the UI. That applies to 66 of the 74, and it is the harder half
of the work: the eight single-authority fields are the tractable ones, and three
of those already have a Hyku authority file behind them.

## By vocabulary set

### Agents: `wikidata`, `naf`, `ulan` — 62 properties

Every agent and role field. This is the bulk of the profile, and by far the
highest-value target if authority lookup is ever wired up.

`creator`, `contributor`, `publisher`, plus the 59 MARC-relator roles:
`addressee`, `architect`, `arranger`, `artist`, `associated_name`,
`attributed_name`, `author`, `autographer`, `binding_designer`, `cartographer`,
`censor`, `choreographer`, `client`, `compiler`, `composer`, `contractor`,
`copyright_holder`, `correspondent`, `costume_designer`, `dedicatee`,
`depicted`, `designer`, `distributor`, `donor`, `editor`,
`editor_of_compilation`, `engraver`, `former_owner`, `honoree`,
`host_institution`, `illustrator`, `instrumentalist`, `interviewee`,
`interviewer`, `issuing_body`, `lithographer`, `lyricist`, `music_copyist`,
`musical_director`, `organizer`, `originator`, `owner`, `performer`,
`photographer`, `printer`, `printer_of_plates`, `producer`,
`production_company`, `restorationist`, `set_designer`, `signer`, `speaker`,
`stage_director`, `stage_manager`, `standards_body`, `surveyor`, `translator`,
`videographer`, `witness`

### Subjects and places

| Property | Sources |
|---|---|
| `subject` | `naf`, `agrovoc`, `fast`, `lcsh`, `tgm`, `wikidata` |
| `spatial` | `geonames`, `naf`, `lcsh` |
| `publication_place` | `naf` |
| `form` | `aat`, `lcsh`, `lcgft` |

### Fields with an existing Hyku authority

These three name vocabularies Hyku already ships a local authority for, so they
are the cheapest to wire up.

| Property | Sources | Hyku authority |
|---|---|---|
| `rights_statement` | `rights_statements` | `rights_statements.yml` |
| `license` | `licenses` | `licenses.yml` |
| `resource_type` | `resource_types` | `resource_types.yml` |

The conversion renames these three from the source's own shorthand
(`rightsstatements`, `creativecommons`, `resourceTypes`) to the shipped
authority filenames, via `CONTROLLED_VALUE_SOURCES`, so `sources` and
`config/authorities/` agree on one identifier.

With every range now `xsd:string`, `resource_type` also agrees with Hyku's
`resource_types.yml`, which uses bare string ids (`Article`, `Audio`) rather
than URIs. That mismatch is resolved.

### Structural and local

| Property | Sources | Notes |
|---|---|---|
| `rdf_type` | `pcdm`, `pcdmuse`, `pcdmff` | PCDM class URIs, set at ingest. |
| `has_work_type` | `utk` | UTK-local vocabulary. |

### `_local` free-text twins

Four properties pair a controlled field with a free-text fallback for values not
present in the authority. Now that every range is `xsd:string` the pairs differ
only in their `controlled_values`, and they disagree on whether the twin should
restate the source vocabulary:

| Controlled | Free text | Twin's `sources` |
|---|---|---|
| `language` | `language_local` | `iso639-2b` (repeats the parent) |
| `resource_type` | `resource_type_local` | `resourceTypes` (repeats the parent) |
| `form` | `form_local` | `['null']` |
| `spatial` | `spatial_local` | `['null']` |

Two restate the parent's vocabulary and two do not, and that inconsistency is
worth resolving rather than leaving. Since `sources` is what drives the
authority behavior, a twin naming a vocabulary is asking for the same picker as
its parent — which defeats the point of a free-text fallback. `language_local`
and `resource_type_local` are the two to check with the metadata owners.

Note also that `resource_type_local` still names the source's `resourceTypes`
shorthand rather than the renamed `resource_types`, since
`CONTROLLED_VALUE_SOURCES` only remaps the parent. If the twin is meant to stay
free text, the fix is to clear its `sources` rather than rename it.

## All 18 vocabularies named

| Abbreviation | Vocabulary |
|---|---|
| `aat` | Getty Art & Architecture Thesaurus |
| `agrovoc` | FAO AGROVOC |
| `creativecommons` | Creative Commons licenses |
| `fast` | OCLC FAST |
| `geonames` | GeoNames |
| `iso639-2b` | ISO 639-2/B language codes |
| `lcgft` | LC Genre/Form Terms |
| `lcsh` | LC Subject Headings |
| `naf` | LC Name Authority File |
| `pcdm` | Portland Common Data Model |
| `pcdmff` | PCDM file format vocabulary |
| `pcdmuse` | PCDM use vocabulary |
| `resourceTypes` | Resource type list |
| `rightsstatements` | rightsstatements.org |
| `tgm` | LC Thesaurus for Graphic Materials |
| `ulan` | Getty Union List of Artist Names |
| `utk` | UTK-local vocabulary |
| `wikidata` | Wikidata |
