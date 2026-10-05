# Controlled vocabularies in the M3 profile

The profile defines 68 properties. 13 declare a `controlled_values.sources` list
naming a real authority, 44 carry the placeholder `sources: ['null']`, and 11 have
no `controlled_values` key at all:

- `date_modified`, `date_uploaded`, `depositor`, `label` and `redirects`, which
  the system sets rather than a depositor.
- The `creators` and `contributors` compounds and their four sub-properties,
  which are controlled through the sub-properties' own `authority:` key instead
  (see "Agents" below).

`controlled_values.sources` is what drives the authority behavior. Naming a
vocabulary here is sufficient: the properties backed by a shipped authority
render their picker without any further wiring, and need no `form.input_type`.

The `sources` value must match the authority it refers to. Where an equivalent
ships with Hyku, the conversion script
(`docs/m3_migration/scripts/convert_allinson_to_m3.rb`) renames the source
profile's own shorthand to the authority's filename (`CONTROLLED_VALUE_SOURCES`),
so the two agree on one identifier:

| Property | Source shorthand | Authority named |
|---|---|---|
| `rights_statement` | `rightsstatements` | `rights_statements` |
| `resource_type` | `resourceTypes` | `resource_types` |

## Authority files

Hyku ships eleven authority files in `hyrax-webapp/config/authorities/`, and the
knapsack has four of its own in `config/authorities/`:

| File | Terms | Used by |
|---|---|---|
| `rights_statements.yml` | 26 | `rights_statement`, `rights_statement_optional` |
| `resource_types.yml` | 14 | `resource_type` |
| `creator_roles.yml` | 18 | the `creators` compound's `role` |
| `contributor_roles.yml` | 44 | the `contributors` compound's `role` |

`config/initializers/knapsack_authorities.rb` makes QA search the knapsack's
directory first, so a same-named YAML there overrides Hyku's. That is how the
knapsack's `rights_statements.yml` and `resource_types.yml` replace Hyku's.

- `rights_statements.yml` holds the 12 rightsstatements.org statements and 14
  Creative Commons licenses in one list. There is no separate `license`
  property: a work's Creative Commons license is recorded as its rights
  statement.
- `resource_types.yml` uses Library of Congress resource type URIs as its ids.
  Hyku's copy, with bare string ids such as `Article` and `Audio`, is unused.

A YAML edit alone does not reach a tenant that already has the vocabulary: terms
are seeded into `qa_local_authorities` when the tenant is created, and served
from those rows afterwards. Apply a change with
`rake utk:vocabularies:reload NAME=<vocabulary>`.

## Controlled properties are ranged `xsd:string`

All 15 controlled properties use `range: xsd:string`. `xsd:anyURI` would make
Hyrax coerce values to `RDF::URI`, whose `as_json` is `{"@id" => "..."}`, which
Solr rejects as a malformed atomic update, so saving a work with such a field
populated would fail. Hyku ranges its own controlled fields as `string` for the
same reason.

`range` drives only the Ruby coercion type, while `controlled_values` names the
authority, so a `string` range costs nothing. The profile's other ranges are the
three machine-readable dates (`xsd:date`), `sequence` (`xsd:integer`), the two
system timestamps (`xsd:dateTime`) and the two PDF display switches
(`xsd:bool`).

## Labels in the catalog

A controlled property stores the term's id, usually a URI. When a work is
indexed, Hyrax asks the configured label service for each value's label and
writes it beside the id, as `<field>_label_sim` and `<field>_label_tesim`. A
facetable controlled property's sidebar facet then lists the labels, and its id
facet is hidden.

The knapsack's `Utk::ControlledVocabularyLabelService` treats every named source
as resolvable, including the remote ones such as `lcsh`, `naf` and `geonames`.
It resolves a remote URI through `UriLabelResolver`, which fetches each URI once
and caches it in `UriCache`. A value it cannot resolve is indexed as its id, so
the catalog shows the URI for that value only.

`config/initializers/hyrax.rb` assigns this service in a `to_prepare` block.
Hyku assigns its own service there too, and Hyku's declines remote authorities,
so the knapsack's has to be assigned after Hyku's on every development reload,
not only at boot.

The compounds' `name` values are not reached by this: they live inside a
`_json_ss` blob. `UtkUriLabelIndexing` resolves those instead, and writes the
labels to `creators_name_sim`, `contributors_name_sim` and their `_tesim`
fields.

## Sources per property

| Sources | Properties |
|---|---|
| `naf`, `agrovoc`, `fast`, `lcsh`, `tgm`, `wikidata` | `subject` |
| `geonames`, `naf`, `lcsh` | `spatial` |
| `aat`, `lcsh`, `lcgft` | `form` |
| `pcdm`, `pcdmuse`, `pcdmff` | `rdf_type` |
| `lcsh` | `provider`, `repository` |
| `naf` | `publication_place` |
| `iso639-2b` | `language` |
| `resource_types` | `resource_type` |
| `rights_statements` | `rights_statement`, `rights_statement_optional` |
| `media_viewer` | `media_viewer` |
| `utk` | `has_work_type` |

Four properties combine several authorities in one `sources` list; the other 9
name one. `lcsh` appears in the most: `subject`, `spatial`, `form`, `provider`
and `repository`.

Questioning Authority resolves **one** authority per lookup, so a field offering
several sources needs either a federated search across all of them or a
source-picker in the UI. That applies to `subject`, `spatial`, `form` and
`rdf_type`.

## By vocabulary set

### Agents: the `creators` and `contributors` compounds

Every agent is recorded in one of two compounds, each a list of `name` and `role`
pairs:

| Compound | `name` | `role` |
|---|---|---|
| `creators` | free text, or a URI such as an LC name authority | `authority: creator_roles` |
| `contributors` | free text, or a URI such as an LC name authority | `authority: contributor_roles` |

The roles are the knapsack's `creator_roles.yml` and `contributor_roles.yml`.
Publisher, for example, is a `contributors` role rather than its own property.

### Subjects, places and institutions

| Property | Sources |
|---|---|
| `subject` | `naf`, `agrovoc`, `fast`, `lcsh`, `tgm`, `wikidata` |
| `spatial` | `geonames`, `naf`, `lcsh` |
| `publication_place` | `naf` |
| `form` | `aat`, `lcsh`, `lcgft` |
| `provider` | `lcsh` |
| `repository` | `lcsh` |

### Local authority files

| Property | Sources | Authority file |
|---|---|---|
| `rights_statement` | `rights_statements` | knapsack `rights_statements.yml` |
| `rights_statement_optional` | `rights_statements` | the same; stands in for `rights_statement` on `DigitalCollection` |
| `resource_type` | `resource_types` | knapsack `resource_types.yml` |
| `media_viewer` | `media_viewer` | Hyku `media_viewer.yml` |

### Structural

| Property | Sources | Notes |
|---|---|---|
| `rdf_type` | `pcdm`, `pcdmuse`, `pcdmff` | PCDM class URIs, set at ingest. |
| `has_work_type` | `utk` | No authority file of that name exists. |

### No free-text twins

`form`, `language`, `resource_type` and `spatial` each hold both authority terms
and free-text values. There is no separate `_local` property for a value missing
from the authority: it goes in the controlled property itself, and is indexed
and displayed as entered.

## Vocabularies named

| Name | Vocabulary |
|---|---|
| `aat` | Getty Art & Architecture Thesaurus |
| `agrovoc` | FAO AGROVOC |
| `contributor_roles` | UTK contributor roles (knapsack file) |
| `creator_roles` | UTK creator roles (knapsack file) |
| `fast` | OCLC FAST |
| `geonames` | GeoNames |
| `iso639-2b` | ISO 639-2/B language codes |
| `lcgft` | LC Genre/Form Terms |
| `lcsh` | LC Subject Headings |
| `media_viewer` | Media viewer choices (Hyku file) |
| `naf` | LC Name Authority File |
| `pcdm` | Portland Common Data Model |
| `pcdmff` | PCDM file format vocabulary |
| `pcdmuse` | PCDM use vocabulary |
| `resource_types` | Resource types (knapsack file) |
| `rights_statements` | rightsstatements.org and Creative Commons (knapsack file) |
| `tgm` | LC Thesaurus for Graphic Materials |
| `utk` | UTK-local vocabulary; no file of that name |
| `wikidata` | Wikidata |
