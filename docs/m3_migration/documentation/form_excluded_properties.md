# Properties with no `form:` block

These 5 properties are deliberately absent from every metadata form. A property
without a `form:` block is never registered as a form field: Hyrax's
`ResourceForm#initialize` builds fields from `form_definitions_for`, which skips
properties whose form options are empty, so `primary_terms` and
`secondary_terms` both miss it and it renders nowhere.

Everything else in the profile (190 of 195) carries a `form:` block.

## Flagged in the source profile

UTK records the exclusion in the definition prose rather than in a key, so the
conversion matches on the sentence "Should not appear in metadata form"
(`FORM_EXCLUSION_PATTERN`). Both of these are autopopulated and must never be
user-editable.

| Property | Reason given in the source |
|---|---|
| `frame_height` | Autopopulated on a `pcdm:File` and added to the IIIF presentation manifest as height/width data, never editable. |
| `frame_width` | Autopopulated on a `pcdm:File` and added to the IIIF presentation manifest as height/width data, never editable. |

## System-managed core properties

Hyrax writes these itself. Hyku's own profile leaves all three without a form
block, and this profile follows that convention.

| Property |
|---|
| `date_modified` |
| `date_uploaded` |
| `depositor` |

## Overridden onto the form

`ark`, `is_part_of` and `resource_link` carry the same "Should not appear in
metadata form" sentence in their definitions, but UTK wants them editable. They
are listed in `FORM_EXCLUSION_OVERRIDES`, which is checked before the prose
pattern, so the source text stays as written while the properties still reach
the form. All three come out as `form: { display: true }`: present, not
required, not primary.

## Worth a second look

`label` does carry a `form:` block, but it is `{ primary: false }` with no
`display` key. Since `secondary_terms` selects on `definition[:display]`, that
combination puts it in neither form section, so it behaves like the five above
despite having a block. Hyku's profile declares `label` exactly the same way, so
this mirrors the reference rather than diverging from it. If `label` should be
editable, it needs `display: true` added.

`label` is also scoped to `Hyrax::FileSet` alone. It is not a core-metadata
property, so `CoreMetadataValidator`'s all-classes rule does not apply to it;
`validate_label_prop` only requires that `available_on` *include* the file set
model. It holds a download filename, which the work types have no use for.
