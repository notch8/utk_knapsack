# Migration scripts

Operator scripts for the UTK migration.  They run by hand, outside the application, one collection
at a time.  `MIGRATION_PLAN.md` at the repo root is the design record; this file is the operating
manual.

**Code lives here, data does not.**  Sheets, lookups, transform output and copy manifests all live
in `tmp/migration/`, which is gitignored.  Nothing here writes into the repository.

## Pipeline

One collection at a time.  The client sheets are already grouped that way, and the whole tenant is
8.0 TB across 1.18M distinct objects, which is not a single operation.  A sheet is the unit of work,
not an identifier prefix: there are 2,477 prefixes and a sheet may span several.

```
tmp/migration/sheets/<collection>.csv         the client's descriptive metadata
  -> bin/migration/collection_lookup.rb       identity and file pointers, for this sheet only
  -> bin/migration/sheet_transform.rb         migration-ready CSV, with a pre-flight report
  -> bin/migration/copy_objects.rb            originals into the destination bucket, server side
  -> bin/migration/stage_derivatives.rb       derivatives out of legacy into the derivatives bucket, once
  -> bin/migration/fill_derivatives.rb        derivatives from the bucket into the destination store
  -> import through the UI                    Bulkrax, "UTK Migration - CSV"
```

```bash
ruby bin/migration/collection_lookup.rb tmp/migration/sheets/ruskin.csv tmp/migration/lookup/ruskin.jsonl
ruby bin/migration/sheet_transform.rb   tmp/migration/sheets/ruskin.csv tmp/migration/lookup/ruskin.jsonl tmp/migration/out/ruskin.csv
ruby bin/migration/copy_objects.rb      tmp/migration/out/ruskin.csv
ruby bin/migration/stage_derivatives.rb tmp/migration/out/ruskin.csv
DST_ROOT=hyrax-webapp/tmp/derivatives ruby bin/migration/fill_derivatives.rb tmp/migration/out/ruskin.csv
```

**Read the transform's report before copying anything.**  It names rows missing a property the
profile requires, and file sets with no digest, which cannot be created at all.

The copies happen **before** the import.  The factory assumes bytes are already in place; it does
not move them.  Every copy script takes `--dry-run`.

### The object manifest is per bucket

`tmp/migration/manifests/objects-<bucket>.txt` is an append-only log of what has been copied,
shared by every collection rather than one per sheet.  It is named after `DST_BUCKET` because a line
records a key, not where it went, so one file per destination is what keeps a copy to dev from
skipping keys that only exist locally.  The derivative scripts keep no manifest: each checks its
destination, the bucket or the disk, for the file at the same size.  Every copy script is safe to
repeat after an interruption.

### Derivatives go through a bucket

Derivatives live on EFS, which no single machine mounts on both sides.  `stage_derivatives.rb`
copies a sheet's derivatives out of the legacy pod into the derivatives bucket once, keyed by their
pairtree path under `derivatives/`; the legacy pod uploads each file to a presigned URL, so the
bytes stay inside AWS and the pod needs no new credentials.  `fill_derivatives.rb` then writes a
sheet's derivatives from the bucket into whichever store the import will read, as many times as
there are environments.  Locally that store is `hyrax-webapp/tmp/derivatives`, bind-mounted into
the container.  A file set with nothing staged is usually correct; see `MIGRATION_PLAN.md`.

### Collections before their members

The sheets reference collections they do not define (`parents: collections:ruskin`).  Import the
collection records first, or the relationship pass accumulates a backlog that only resolves once
the collection exists.

## The scripts

- **`pull_lookup.rb`** dumps every object carrying a `bulkrax_identifier` out of production Solr:
  id, identifier, sha1, mime type, size and label.  That is the join key and the file pointer;
  descriptive metadata comes from the sheet.  One `cursorMark` pass over 2,688,106 rows.
  After this, production Solr is read only per sheet: by `collection_lookup.rb`, and by
  `stage_derivatives.rb`'s tenant check.
- **`collection_lookup.rb`** pulls the lookup for one sheet, querying Solr by the identifiers the
  sheet actually names.  Exits non-zero if any identifier went unmatched, so a sheet referencing
  something production does not have is caught before the transform runs.
- **`sheet_transform.rb`** joins a client sheet to a lookup and emits a migration-ready sheet.  It
  reports rows missing a property the profile requires and file sets with no digest, neither of
  which fails anywhere else: Valkyrie resources carry no validations, and a digest-less file set
  only surfaces as a failed entry after the import has started.  It adds the production UUID,
  replaces `remote_files` with the `sha1` pointer so nothing is re-downloaded, renames `Image` to
  `StillImage`, and collapses the flat relator columns into the `creators` and `contributors`
  compounds.  The role map comes from `config/authorities/{creator,contributor}_roles.yml`, so the
  emitted `role` is the term the form validates against, and a new term is picked up automatically.
- **`copy_objects.rb`** copies a sheet's originals into the destination bucket with server-side
  `copy_object`, so no bytes pass through the application.  Each file set gets its own copy at
  `<file set id>/<uuid>`, the key `Bulkrax::UtkMigrationObjectKey` derives and the factory writes
  into `file_identifier`, so the two cannot disagree.  Threaded, resumable, and skips anything the
  per-bucket manifest already holds.
- **`stage_derivatives.rb`** copies a sheet's derivatives from the legacy EFS into the derivatives
  bucket.  It reaches the pod through `UTK_CONTEXT` rather than the current kubectl context, reads the
  legacy root from the pod's `HYRAX_DERIVATIVES_PATH`, and refuses to run unless the tenant answers as
  `UTK_CNAME`.  Files already staged at the same size are skipped.  Upload URLs are signed per batch
  and expire after an hour, so run a sheet heavy in audio or video with `BATCH=1`.
- **`fill_derivatives.rb`** copies a sheet's derivatives from the bucket into `DST_ROOT`, which is
  required rather than defaulted: production sets `HYRAX_DERIVATIVES_PATH`, a local stack leaves it
  unset and Hyrax uses `tmp/derivatives`, and writing to the wrong root looks like success.  It
  writes to a directory this machine can reach, so for now it fills a local stack only.

## Environment

Every credential, host and namespace comes from the environment.  Two bucket names carry defaults
in the source, `besties-fcrepo` for the source and `utk-poc` for the destination and the derivatives
bucket, all overridable.
`AWS_REGION` defaults to `us-east-2` while `besties-fcrepo` is us-west-2, so a default-everything
run is a cross-region copy and billable egress.  Set the region deliberately.

| | Used by |
| --- | --- |
| `SOLR_HOST`, `SOLR_PORT`, `SOLR_ADMIN_USER`, `SOLR_ADMIN_PASSWORD`, `TENANT` | the two lookup scripts |
| `SRC_BUCKET`, `SRC_REGION`, `DST_BUCKET`, `AWS_REGION`, `THREADS`, `COPY_MANIFEST` | `copy_objects.rb` |
| `UTK_CONTEXT`, `UTK_NAMESPACE`, `UTK_DEPLOYMENT`, `UTK_CONTAINER`, `UTK_CNAME`, `UTK_TENANT`, `DERIVATIVES_BUCKET`, `AWS_REGION`, `BATCH` | `stage_derivatives.rb` |
| `DST_ROOT`, `DERIVATIVES_BUCKET`, `AWS_REGION` | `fill_derivatives.rb` |
