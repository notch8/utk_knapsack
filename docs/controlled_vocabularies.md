# Controlled vocabularies in the migrated profile

74 of the 195 properties declare a `controlled_values.sources` list naming a real
authority. Of the rest, 117 carry the placeholder `sources: ['null']` and 4 have
no `controlled_values` key at all (`date_modified`, `date_uploaded`, `depositor`
and `label`, which the conversion synthesizes rather than reading from the
source). All 121 are free text.

**Nothing in Hyrax reads any of this.** `controlled_values` is not consulted by
the schema loader or by any validator; it passes validation because the
`properties.*` subschema does not set `additionalProperties: false`. It is
documentation of intent, and the intent is not yet wired to anything.

What *is* live is the `range`: 72 of these 74 properties are typed
`xsd:anyURI`, so their values are URIs. Without an authority behind them, the
deposit form renders a plain text box and a depositor is expected to paste a URI
by hand. Closing that gap needs two things the profile does not currently have:

1. A Questioning Authority YAML in `config/authorities/`, and
2. An `input_type` on the property pointing at it.

The knapsack has **no `config/authorities/` directory yet**. Hyku ships eleven
authority files, three of which already correspond to vocabularies named below.
`config/initializers/knapsack_authorities.rb` makes QA search the knapsack's
authorities directory first, so a same-named YAML placed there overrides Hyku's.

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
| `rights_statement` | `rightsstatements` | `rights_statements.yml` |
| `license` | `creativecommons` | `licenses.yml` |
| `resource_type` | `resourceTypes` | `resource_types.yml` |

Note Hyku's `resource_types.yml` uses bare string ids (`Article`, `Audio`),
while this profile types `resource_type` as `xsd:anyURI`. The two do not
currently agree, so that pairing needs a decision before it is used.

### Structural and local

| Property | Sources | Notes |
|---|---|---|
| `rdf_type` | `pcdm`, `pcdmuse`, `pcdmff` | PCDM class URIs, set at ingest. |
| `has_work_type` | `utk` | UTK-local vocabulary. |

### `_local` free-text twins

Four properties pair a controlled field with a free-text fallback for values not
present in the authority. Every twin is typed `xsd:string` rather than `anyURI`,
but they disagree on whether to restate the source vocabulary:

| Controlled (`anyURI`) | Free text (`string`) | Twin's `sources` |
|---|---|---|
| `language` | `language_local` | `iso639-2b` (repeats the parent) |
| `resource_type` | `resource_type_local` | `resourceTypes` (repeats the parent) |
| `form` | `form_local` | `['null']` |
| `spatial` | `spatial_local` | `['null']` |

Two restate the parent's vocabulary and two do not. Since nothing reads
`controlled_values`, the inconsistency is currently harmless, but it makes the
profile misleading to read: `language_local` appears controlled by `iso639-2b`
while being a free-text field. Worth normalizing with the metadata owners, in
whichever direction they prefer.

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
