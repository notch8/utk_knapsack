# Migration tool

A small standalone program for the UTK migration, run by hand on your own machine, never inside
Docker or the Rails app.  One collection at a time.  `MIGRATION_PLAN.md` at the repo root is the
design record; this file is the operating manual.

## TL;DR: one collection

```bash
bin/migration/prepare_sheet tmp/migration/sheets/collections_ruskin.csv --profile n8 --dry-run
bin/migration/prepare_sheet tmp/migration/sheets/collections_ruskin.csv --profile n8
```

It asks before doing anything:

```
Dry run of all 195 works from collections_ruskin.csv on local as n8. Proceed? (y/N)
```

Then it looks the sheet up in legacy Solr, transforms it, copies the originals, stages and fills the
derivatives, and prints the file to import.  Import that file at `/importers/new` with the
**UTK Migration - CSV** parser.

| Option | Effect |
| --- | --- |
| `--profile NAME` | AWS profile to use, as with the `aws` CLI (or set `AWS_PROFILE`) |
| `--dev`, `--staging`, `--prod` | destination; none means local |
| `--limit N` | only the first N works, with everything under them |
| `--dry-run` | report what would happen; copy nothing |
| `--skip-missing` | set aside works legacy cannot supply instead of stopping |
| `--yes`, `-y` | skip the confirmation prompt (required when there is no terminal) |

It stops at the first failure, including any stop line in the transform's report: unmatched
identifiers, missing required properties, file sets with no digest, unknown role columns.  A real
run on prod asks you to type `prod` instead of `y`.

**`--limit N`** saves its slice as `tmp/migration/sheets/<sheet>-firstN.csv`, so its output never
overwrites a full run's, and leaves out the Collection row, which is imported separately first.

**`--skip-missing`** leaves out, whole and with everything under it, any work that is not in legacy
Solr or that has a file set with no digest or with its original missing from `besties-fcrepo`.
Each is listed with its reason in `tmp/migration/out/<sheet>-flagged.csv`, for a normal import.
Missing required properties and unknown role columns still stop the run: those are fixed in the
sheet.

Use `BATCH=1` for a sheet heavy in audio or video: upload and download URLs are signed per batch and
expire after an hour.

### Destinations

| Destination | Flag | AWS profile | Originals go to | Derivatives fill |
| --- | --- | --- | --- | --- |
| local | none | `n8` | `utk-poc` | `hyrax-webapp/tmp/derivatives` |
| dev | `--dev` | `utk` | `utk-staging-repository-dev-…` | the dev web pod |
| staging | `--staging` | `utk` | `utk-staging-repository-staging-…` | the staging web pod |
| prod | `--prod` | `utk` | `utk-production-repository-production-…` | the prod web pod |

The `utk` profile cannot reach `utk-poc`, so on a deployed environment derivatives are staged under
its repository bucket's own `derivatives/` prefix until a shared derivatives bucket exists.
`DST_BUCKET`, `DERIVATIVES_BUCKET` and `DST_POD` still override a preset.

## Setting up on a new machine

- **Ruby 3.2 or newer, and its gems:** `cd bin/migration && bundle install`.  The tool has its own
  `Gemfile`, separate from the app's, and `prepare_sheet` loads it by itself.
- **kubectl**, with a context for the legacy cluster and one for the destination cluster.
- **Access:** exec rights on the legacy pod (`utk-hyku-production`), read on `besties-fcrepo`, and
  write on the destination bucket.
- **Your names for things:** profile and context names are per person.  The examples use `n8` and
  `utk` for AWS profiles and `r2-besties` and `utk-staging` for kubectl contexts; set yours with
  `--profile`, `UTK_CONTEXT` (the legacy cluster) and `DEST_CONTEXT` (the destination cluster,
  `utk-staging` for dev and staging, `utk-production` for prod).
- **Input files:** UTK's collection sheets and the collection records sheet, both downloaded as CSV
  from the shared Google Drive into `tmp/migration/sheets/`.  The collection records go through the
  stock **CSV - Comma Separated Values** parser before any work sheet, since work sheets reference
  collections they do not define.

**Code lives here, data does not.**  Sheets, lookups and transform output live in `tmp/migration/`,
which is gitignored.

## How it works

1. **Lookup.**  The sheet's identifiers are sent into the legacy pod, where a small script queries
   UTK's Solr with `rsolr` and returns each record's id, sha1, mime type, size and label.  The
   credentials never leave the pod.
2. **Transform.**  Joins the sheet to the lookup and writes the import CSV: adds the production
   UUID and the `sha1` pointer in place of `remote_files`, renames `Image` to `StillImage`, and
   collapses the flat relator columns into the `creators` and `contributors` compounds using the
   role authorities in `config/authorities/`.  Its report is the only place a missing required
   property is caught: the migration factory saves resources directly, with no validations.
3. **Copy originals.**  One server-side `copy_object` per file set, from `besties-fcrepo` to
   `<file set id>/<uuid>`, the key `Bulkrax::UtkMigrationObjectKey` derives and the factory records
   as `file_identifier`, so the two cannot disagree.  Over 5 GB it switches to a multipart copy.
4. **Stage derivatives.**  Derivatives live on EFS, which no single machine mounts on both sides, so
   they move through S3: the legacy pod uploads a sheet's derivatives to presigned URLs under
   `derivatives/<pairtree path>`, keeping the bytes inside AWS.
5. **Fill derivatives.**  From the bucket into the store the import reads: the local folder, or the
   destination web pod, which downloads presigned URLs into its own `HYRAX_DERIVATIVES_PATH`.

Every copy step checks its destination for each file at the same size and skips what is already
there, so any run is safe to repeat from any machine.  Nothing keeps a log of what was copied.  A
file set with no derivatives is usually correct; see `MIGRATION_PLAN.md`.

## Layout

```
bin/migration/
  prepare_sheet            the command
  lib/migration/
    options.rb             flags
    confirmation.rb        the prompt
    target.rb              local, dev, staging and prod presets
    sheet.rb               reading, slicing, finding a row's top-level work
    transform.rb           the import CSV
    preflight.rb           its stop lines: unmatched, missing required, no digest, unknown columns
    profile.rb             required properties and role columns, from the metadata profile
    originals.rb           step 3
    derivatives/           steps 4 and 5
    pod.rb                 runs a script in a pod over kubectl
    pod/                   the scripts that run inside the pods
    report.rb              the step, file and failure lines
  spec/                    cd bin/migration && bundle exec rspec
  pull_lookup.rb           separate one-off: dumps every bulkrax_identifier from legacy Solr
```

## Environment

| Variable | Default | Used for |
| --- | --- | --- |
| `UTK_CONTEXT`, `UTK_NAMESPACE`, `UTK_DEPLOYMENT`, `UTK_CONTAINER` | `r2-besties`, `utk-hyku-production`, `deploy/utk-hyku-production-hyrax`, `hyrax` | reaching the legacy pod |
| `UTK_TENANT`, `UTK_CNAME` | UTK's Solr collection and cname | the lookup and the tenant check |
| `SRC_BUCKET`, `SRC_REGION` | `besties-fcrepo`, `us-west-2` | the originals' source |
| `DST_BUCKET`, `DERIVATIVES_BUCKET`, `DST_POD`, `DST_ROOT`, `DEST_CONTEXT` | from the destination preset | where things go |
| `AWS_REGION` | `us-east-2` | the destination buckets |
| `THREADS`, `BATCH` | `8`; `50` to stage, `200` to fill | copy threads, files per derivative batch |
