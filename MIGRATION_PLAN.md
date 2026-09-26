# UTK migration plan

**BLUF.**  UTK's Hyrax 3 repository moves into this knapsack by minting metadata that points at the
bytes it already has.  Preservation files are copied server side into each environment's bucket under
the key an upload would get, derivatives are copied by pairtree, and nothing is uploaded or
regenerated.  One collections sheet is ingested first, then one
work sheet per collection, each through Bulkrax with a migration-only object factory that persists
directly.  Measured against a real UI deposit, the result is identical on every field that matters
except the two the migration exists to change.  One thing stands between here and the real run:
members are not ordered by `sequence` and get no thumbnail until a post-import pass exists.

The source is the `utk-hyku-production` namespace, where UTK is the `digitalcollections.lib.utk.edu`
tenant of a shared deployment.

**The rule that shapes everything: move no bytes through the application, and regenerate nothing.**
Preservation files and derivatives already exist.  The migration mints metadata that points at them.

**All of this is temporary.**  The object factory, the parser, the entry classes, the
characterization job and the scripts exist to run one migration, against one tenant, supervised,
once, and are deleted afterwards.  Read them as scaffolding rather than as additions to the
knapsack: a defect that needs a misconfigured tenant, an unattended run, or a second parser to
surface is not one this code lives long enough to meet.

## What has been proven

The ingest is built and runs from the importer form, and it has been measured against the thing it
has to match.  The same two file sets were created twice: once from a CSV through the migration
parser, and once by depositing through the New Work form as a logged-in user, which runs the full
`change_set.create_work` transaction.  Identical on both paths: depositor, visibility, admin set,
member count and order, ACLs on the work *and* its file sets, workflow state, file count, PCDM uses,
`mime_type`, `height`, `width`, `format_label`, and the indexed `height_is`, `width_is`,
`file_format_tesim`, `visibility_ssi`.

Different by design, and the whole point: `checksum` holds the real sha1 rather than Hyrax's md5,
and `file_identifier` addresses bytes already in the bucket.

One gap which will be addressed later: `representative_id` and `thumbnail_id` are unset, so a work
shows the placeholder thumbnail and the post-import ordering pass fixes it.

## The pipeline

**Two sources, joined on the identifier.**  All descriptive metadata comes from UTK's sheets,
including the URIs for controlled vocabulary.  All identity and file information comes from the
legacy Solr index.  Fedora is not a source for either.

**One sheet at a time, and a sheet is a collection.**  8.0 TB across 1.18M objects is not a single
operation, and the client's sheets are already grouped that way.  Step 1 is the exception, a single
tenant-wide pass run once and reused by every sheet after it.

**The first sheet is the collections sheet.**  UTK supplies one sheet carrying every
`DigitalCollection` record, and it is ingested before any other.  Every work sheet after it
references them by identifier (`parents: collections:ruskin`).  The migration parser cannot route
collection rows, so the collections sheet goes through Bulkrax's stock `CSV - Comma Separated
Values` parser instead, which imports `DigitalCollection` rows as they are.

**Local first, then staging, then production, on the same file.**  A sheet is transformed once,
locally.  The result is imported locally and checked, and then that CSV is promoted unchanged: the
file Bulkrax holds from the local import is what staging imports, and staging's is what production
imports.  Nothing is re-transformed between environments.  The copy steps run in every environment
before its import, since the CSV carries pointers and they have to resolve where it runs; a copy
that was skipped fails characterization with `FileNotFound` rather than passing.

**Local proves the sheet, not the viewer.**  A local import checks what the migration decides:
keys, bytes, checksums, characterization, thumbnails, membership.  The IIIF viewer is checked on a
deployed environment only.  Locally nothing serves `/iiif/2/`, since the tenant-host IIIF URLs
depend on the deployed nginx proxy, and the legacy Lambda reads `besties-fcrepo`, which holds no
object under the new keys.

Per sheet:

1. **Extract** identity and file info from the legacy Solr.  `pull_lookup.rb` reads six fields:
   `id`, `bulkrax_identifier_tesim`, `digest_ssim`, `mime_type_ssi`, `file_size_lts` and
   `label_tesim`.  That is the join key and the file pointer, and nothing else.  Once per tenant,
   locally, reused by every sheet.
2. **Transform** the client's CSV.  `prepare_sheet`'s transform joins their sheet to the extract and adds
   `sha1`, `mime_type`, `file_size`, `original_filename`.  It also reports rows missing a property
   the profile requires, which is the only place such a gap is caught: the factory saves resources
   directly, so a missing required value persists silently.  Once, locally; its output is the
   artifact.
3. **Copy preservation files** into the bucket the environment reads.
4. **Copy derivatives** into the environment's derivative store.
5. **Ingest** with Bulkrax and the migration factory.  Members arrive unordered and the work gets
   no thumbnail; ordering by `sequence` is a separate pass that is not built yet.  See
   **Member order**.
6. **Reconcile**.

Steps 3 through 6 run in each environment in turn, local, then staging, then production.  Steps 3
and 4 must precede step 5 in each; the factory assumes bytes are in place.

Pointing the IIIF service at the destination bucket is a one-time cutover rather than pipeline work,
and which bucket that is remains open; see **Open questions**.

## Before the real run

- **The derivative root is the one the destination reads.**  The fill writes to the destination's
  own `HYRAX_DERIVATIVES_PATH` or, locally, `DST_ROOT`; writing to the wrong one looks exactly like
  success.
- **The collections sheet has been ingested.**  A work sheet run before it accumulates a
  relationship backlog that only resolves once the collections exist.
- **The importer form's Visibility is set deliberately.**  A row with no `visibility` takes that
  field's value, and the form defaults it to `open`.  4,681 rows across the sheets are blank, 4,366
  of them in `gsmrc_pcard00`; an unattended default publishes them.

## Where things live

| | Store | Addressed by | Size |
| --- | --- | --- | --- |
| Preservation files | S3 `besties-fcrepo`, us-west-2 | bare sha1 hex | 7.79 TiB / 1,177,142 objects are UTK's |
| Derivatives | EFS at `/app/samvera/derivatives` | pairtree of the **file set id** | ~140 GB are UTK's, measured 2026-09-23; see below |
| IIIF | Lambda function URL, us-west-2 | the sha1 | derives per request |

The derivative pairtree is the file set id chopped every two characters, hyphens included, kind as
suffix: `96/0e/8d/cb/-b/f4/2-/44/6d/.../6b/7c-thumbnail.jpeg`.  Because file set ids are preserved,
this application computes the identical path, so derivatives lift across unchanged.

Per image file set the derivatives are `-thumbnail.jpeg` plus `-txt.txt`, `-xml.xml`, `-json.json`
(OCR output from iiif_print).  A IIIF server cannot produce those, and the set must be copied all or
nothing, since the coordinates only match the text they came from.

Sizes, measured 2026-09-23 from UTK's Solr and the EFS: every audio and video file set, and a sample
of 300 (200 for PDF) of each other type.  Image and PDF derivatives average 70 to 150 KB per file set,
about 55 GB extrapolated.  Audio and video are few but large, about 83 GB.  The largest single file is
a 2.4 GB `-mp4.mp4` beside a 2.2 GB `-webm.webm`.

| Type | File sets | With derivatives | Size | Kinds |
| --- | --- | --- | --- | --- |
| `video/mp4` | 106 | 81 | 30.1 GB | mp4, webm, thumbnail |
| `audio/mpeg` | 869 | 819 | 48.9 GB | mp3, ogg |
| `audio/x-wave` | 733 | 66 | 4.3 GB | mp3, ogg |
| quicktime, matroska, dv, mp4a | 66 | 0 | | |
| `image/jp2`, `image/jpeg` | sample | all | 70 to 110 KB each | thumbnail, OCR |
| `image/tiff` | sample | 72% | 82 KB each | thumbnail, OCR |
| `application/pdf` | sample | 73% | 152 KB each | thumbnail |

**A file set without derivatives is usually correct.**  The legacy application builds them only when
the parent Attachment's `rdf_type` contains `IntermediateFile`, or the work is a `Pdf` or
`GenericWork` (`Hyrax::ConditionalDerivativeDecorator` in utk-hyku, since 2023-02).  Preservation
masters are skipped by design: 731 of 733 WAVs and every QuickTime and DV file are
`PreservationFile`, and their mp3 or mp4 sibling carries the derivatives.  The migration copies
what exists and generates nothing for the rest.  The exception is about 24 intermediate mp4s with no
derivatives, which the rule says should have them.  They are treated as broken, and their derivatives
are generated by hand after import.  `rdf_type` is stored on the Attachment as
`rdf_type_ssm`, which Solr can return but not facet.

## Shape change

```
legacy:  Image      ──▶ Attachment ──▶ FileSet        ──▶ Hydra::PCDM::File
target:  StillImage ────────────────▶ Hyrax::FileSet ──▶ Hyrax::FileMetadata
```

The Attachment layer only existed because a pre-flexible file set could not carry metadata of its
own.  Flexible metadata removes the need.  **UTK handles the Attachment collapse in the CSVs they
supply**, so it is not this pipeline's job.

Each `Hydra::PCDM::File` becomes one `Hyrax::FileMetadata`: a Postgres row and an S3 object joined
only by `file_identifier`.  That separation is what lets the migration write metadata while leaving
bytes untouched.

**Relator columns collapse into two compounds.**  The client's sheets carry one flat column per
role; the profile replaced those with `creators` and `contributors`, each a list of
`{name, role}`.  The transform builds its role map from the two role authorities: a
column whose name, minus an optional `utk_` prefix, names a term in `creator_roles.yml` or
`contributor_roles.yml` is a role column, the file decides the compound, and the term's `id` is the
`role` value, `Photographer` not `photographer`, since the field is controlled and validated against
that authority.  The value, URI or string, goes in `name`: the compound has no `uri` field, a URI is
dereferenced to its label at index time, and a string is already the label.  That is what lets
`photographer` (all URIs) and `utk_photographer` (all strings) land in the same compound.  Across
UTK's 40 sheets every one of the 29 role columns resolves, 11,952 of the 30,435 values are URIs,
and `publisher`, `contributor` and `creator` collapse too, since their flat properties are gone.

Derivative uses follow Hyrax's own `MigrateFilesToValkyrieJob`: `thumbnail` to `ThumbnailImage`,
`txt`/`xml`/`json` to `ExtractedText`, anything else to `ServiceFile`.

## Decisions taken

| Decision | Why |
| --- | --- |
| Re-characterize, do not lift | Running FITS locally gives the complete set, needs no legacy access, and doubles as a fixity pass.  Solr holds only ~6 fields and collapses `color_space` to `srgb` |
| Persist directly, not through the transaction | 3.0x slower and 5.6x the queries, and it would re-introduce `add_file_sets`, which copies bytes.  See below |
| Keep the FileSet id, not the Attachment id | Derivative paths and IIIF identifiers keep resolving.  Attachment ids stop existing |
| Do not attach file sets in the factory | Lock contention.  See **Member order** |
| Migrate the latest file version only | No history is carried across |
| Solr's `date_uploaded`/`system_create` become the migration date | Those fields record when a record entered *this* system.  The dates a reader wants travel in descriptive metadata |
| Originals are keyed like an upload | `<file set id>/<uuid>`, the shape `Valkyrie::Storage::Shrine` gives a deposit, so one bucket holds one shape.  The IIIF auth gate reads the file set id from the first segment, and each file set owns its object, so a delete touches nothing else.  The uuid is v5 of `<file set id>/<sha1>` under `URL_NAMESPACE` (`Bulkrax::UtkMigrationObjectKey`), so the copy and the factory derive it independently and a re-run lands on the same key.  Costs a copy per file set where 98,310 share a sha1 |
| Derivatives stay on a mounted volume | `derivatives_storage_adapter` defaults to disk and every deployment checked runs it that way.  S3 would mean genuinely moving bytes, since `ValkyrieUpload` mints its own key |

## Traps

Each of these fails silently.

- **`checksum` must hold the sha1.**  iiif_print builds `digest_ssim` from `checksum`, and that is
  the IIIF identifier for any file set without `storage_file_identifier_ss` indexed.  Get it wrong
  and the bytes are intact while those images are unresolvable, with nothing failing at ingest.
- **Pass `parser_mapping: Hydra::Works::Characterization.mapper`**, the unmerged default.  Hyrax
  merges `original_checksum: :checksum`, which writes FITS's md5 over the sha1.
- **Pass `**Hyrax.config.characterization_options`.**  Without it the default is the FITS CLI, which
  is not on these images.  It returns a clean job and no values.
- **A derivative is a `FileMetadata`, not a file on disk.**  `FileSet#thumbnail_id` is not stored;
  it is `find_thumbnail`, a query for the first file with the `ThumbnailImage` use.  A file set
  with none shows the placeholder no matter what sits on disk.
- **Deleting a migrated work deletes its copy of the master.**
  `file_set.delete_all_file_metadata` ends with
  `Valkyrie::StorageAdapter.delete(id: resource.file_identifier)`.  The object is that file set's
  alone and the destination buckets are versioned, so the delete leaves a recoverable delete marker
  and `besties-fcrepo` is never touched.  File sets imported before the rekey still point at
  `shrine://<sha1>`, which other file sets may share.
- **Three derivatives share `ExtractedText` (from IIIF Print)**, and `find_extracted_text` returns
  the first, so `#extracted_text` usually answers with word-coordinate JSON rather than text.  Read
  the `text/plain` one explicitly.  Upstream's mapping, not ours.

## Why not the stock transaction

The factory persists with `Hyrax.persister.save` and calls the steps that matter by hand: the admin
set, the depositor, the permission template plus visibility, `WorkflowFactory` for the Sipity
entity, and `AccessControlList.copy_permissions` from the parent onto each file set.  Two reasons
not to run `change_set.create_work` instead:

- **Cost.**  Measured, 25 works each: direct persistence plus indexing is 12 queries and 0.059s per
  work; the transaction is 67 and 0.179s.  Roughly 25 hours against 75 for 1.5M works, before file
  sets.
- **Validation is a policy question.**  `change_set.validate` refuses a work missing `provider`,
  `rights_statement`, `primary_identifier` or `has_work_type`.  Legacy rows do not always carry
  them.  The sheet pre-flight reports those rows instead, which is the right place to decide.

## Member order

`sequence` is the only ordering data at scale, and nothing reads it during ingest.  Bulkrax orders
by Entry row id, so a 120 page sheet on three workers came out with 40 inversions across 119
adjacent pairs.

**The factory does not attach file sets to their work, deliberately.**  Attaching as each file set
job landed put every worker on one lock keyed by the parent, and that sheet lost 12 of 120 file sets
to `UnableToAcquireLockError`.  Bulkrax's relationship pass attaches them after the run instead.

**Ordering is the system's job once, and a person's thereafter.**  A pass at the end of the import rewrites
`member_ids` by `sequence` and sets `representative_id` and `thumbnail_id`.  The end of the import is
the only moment `sequence` is authoritative: it is what the legacy system recorded, and nothing in this
application has had an opinion yet.  Any reordering after that is a curator's, done by hand, and the pass
must not run again and undo it.

**`sequence` comes from the client's sheet**, passed through untouched; the transform neither
derives nor cleans it.  Some sheets carry no `sequence` column at all, which means the collection is
not paginated rather than that a value is missing, and **those works are not sorted**.  They keep the
order they arrived in.

## Reconciliation

**Not built.**  This is the specification.  It runs per collection, driven from the transformed
sheet rather than the repository, so an object that never arrived is a missing row rather than an
absence nobody notices.

Per file set:

1. A resource exists at the production UUID.
2. Exactly one `OriginalFile`.  Re-importing a sheet over existing objects is safe, measured: the
   row is found at its preserved id and takes Bulkrax's update path, leaving files untouched.
3. `file_identifier` is `shrine://`.  The `disk://` fallback exists for local runs; in a deployment
   it means S3 was misconfigured and every file set points at nothing.
4. The identifier's remainder equals `Bulkrax::UtkMigrationObjectKey.for` of the row's `id` and
   `sha1`.
5. `checksum` equals that same `sha1`.  The silent one.
6. The object exists in the destination bucket, as a set difference against a bucket listing.
7. Every derivative on the source pairtree has a `FileMetadata` with the matching `pcdm_use`, and
   its path resolves.

Per work:

8. Member count equals the sheet's file set count.
9. `representative_id` and `thumbnail_id` set when the work has an image member.
10. Member order matches `sequence`.

## Not built yet

- **Collections.**  UTK supplies the records in one sheet, ingested first.  Membership wiring and
  branding assets are still open; branding is a third store, keyed by collection id both on disk and
  in `collection_branding_infos`.
- **Depositor users** must exist before ingest.  `User` is global; per-tenant roles are not.
- **Audio and video** get nothing from an image IIIF service.  Audio thumbnails are a static asset,
  so they need no derivative.
- **Re-running over existing ids** leaves stale activity entries in Redis, which nothing deletes.
  Only bites on a re-run; production ids are unique.

## Open questions

- **The 20,878 file sets with no digest.**  Nothing to point at, so they cannot be created.

  | Pattern | Count | Reading |
  | --- | --- | --- |
  | the work's other datastreams have digests | 20,302 | derivative generation failed; 19,911 are ALTO |
  | nothing under the work has a digest | 509 | looks like a failed ingest |
  | the work has digests but its `OBJ` does not | 129 | derivatives but no preservation master |

  So ~316 works arrive with no master, against 20,302 missing only a derivative the new system
  generates anyway.  ALTO is a derivative rather than a file set in the new model, which may mean
  most of these should not migrate as file sets at all.
- **Which bucket does the IIIF service read?**  The legacy Lambda reads `besties-fcrepo`.  Originals
  are copied under new keys, so the destination cannot be `besties-fcrepo`, and whatever serves
  IIIF has to read the destination bucket.  `DeveloperAccess` cannot read Lambda config.
- **Region.**  `besties-fcrepo` is us-west-2, `utk-poc` is us-east-2.  Cross-region copy of 7.79 TiB
  is billable egress.
- **66 WAVs have derivatives** although the rule skips preservation files, possibly from before the
  rule existed.  Not verified; harmless either way, since they copy like any other.
- **13 m4a files are tagged `ExtractedText`**, which looks like a mislabel.  Ask UTK.
- **`xresolution` holds `"9"`** on every Attachment sampled, which is not a plausible dpi.  Ask UTK
  before carrying it forward.

Settled: **access control** (the IIIF endpoint serves any image by sha1 with no auth; production
already behaves this way and UTK accepted inheriting it); **embargoes and leases** (zero records
carry them); **full text** (a file set's `all_text_tsimv` comes from iiif_print reading its `txt`
derivative, a work's from `HykuIndexing` reading its `text/plain` children, nothing needed writing
here; the two upstream bugs that discarded it are samvera/hyku#3294 and notch8/iiif_print#413).

## Reference

- Legacy index as of 2026-09-09: `Attachment` 1,502,376, `Image` 39,463, `Book` 20,010, `Pdf` 8,443,
  `CompoundObject` 1,953, `Audio` 867, `Video` 97.
- UTK's Solr collection is `56e0eb81-c2d5-4d5d-9171-b251bf7299a4`.  `SOLR_COLLECTION_NAME` names an
  empty collection and reads as "there is no data".  `_ssm` fields are stored but not indexed, so
  any census must read stored fields off documents rather than count query hits.
- Scripts live in `bin/migration/`.  Their working data (sheets, lookups, output) lives
  in `tmp/migration/`, which is gitignored.
