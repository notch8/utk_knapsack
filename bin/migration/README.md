# Migration tool

A small standalone program for the UTK migration, run by hand on your own machine, never inside
Docker or the Rails app.  One collection at a time.  `MIGRATION_PLAN.md` at the repo root is the
design record; this file is the operating manual.

## TL;DR: one collection

```bash
bin/migration/prepare_sheet tmp/migration/sheets/collections_ruskin.csv --dry-run
bin/migration/prepare_sheet tmp/migration/sheets/collections_ruskin.csv
```

It asks before doing anything:

```
Dry run of all 195 works from collections_ruskin.csv on local as n8. Proceed? (y/N)
```

Then it looks the sheet up in legacy Solr, transforms it, copies the originals, stages and fills the
derivatives, and prints the file to import.  Import it with `import_sheet` (below), or at
`/importers/new` with the **UTK Migration - CSV** parser.

| Option | Effect |
| --- | --- |
| `--profile NAME` | AWS profile to use, as with the `aws` CLI (or set `AWS_PROFILE`); default `n8` locally, `utk` on dev, staging and prod |
| `--dev`, `--staging`, `--prod` | destination; none means local |
| `--limit N` | only the first N works, with everything under them |
| `--members N` | each work keeps only its first N members (file sets, or child works with theirs), by `sequence`, unsequenced last |
| `--dry-run` | report what would happen; copy nothing |
| `--skip-missing` | set aside rows legacy cannot supply instead of stopping |
| `--recheck` | ignore the progress file and check every original and derivative again |
| `--yes`, `-y` | skip the confirmation prompt (required when there is no terminal) |

It stops at the first failure, including any stop line in the transform's report: unmatched
identifiers, missing required properties, file sets with no digest, unknown role columns, values
off their local vocabulary.  A real run on prod asks you to type `prod` instead of `y`.

Every unmatched identifier is written to `tmp/migration/out/<sheet>-unmatched.txt`, empty when there are
none; the stop line names only the first five.  A derivative that fails to stage stops the run, unless its file set is a
PDF or an intermediate file whose thumbnail also failed: the import regenerates every derivative of a
file set like that, since it arrives with no thumbnail.

A rerun resumes: `tmp/migration/out/<sheet>-progress.json` records which of steps 3 to 5 finished and,
within staging and filling, how many file sets are done, so it skips them instead of checking each
one again.  It applies only while the transformed sheet is unchanged; delete it or pass `--recheck`
to check everything.  A batch with a failure stops the count, so the rerun retries from there.

**`--limit N`** saves its slice as `tmp/migration/sheets/<sheet>-firstN.csv`, so its output never
overwrites a full run's, and leaves out the Collection row, which is imported separately first.
**`--members N`** adds `-membersN` to that name and keeps each work's first N pages by `sequence`,
so a compound or book work arrives with its opening pages and its legacy thumbnail.

**`--skip-missing`** leaves out any file set that is not in legacy Solr, has no digest, or has its
original missing from `besties-fcrepo`, and imports its work without it.  A work that is not in
legacy Solr is left out with everything under it, and a child work only takes its own subtree.
Each row left out is listed with its model, parents and reason in
`tmp/migration/out/<sheet>-flagged.csv`, for a normal import.
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

## Importing a prepared sheet

```bash
bin/migration/import_sheet tmp/migration/out/collections_ruskin.csv
bin/migration/import_sheet tmp/migration/out/collections_ruskin.csv --dev
```

It creates the importer the form's **Create and Import** would, named after the file, with the
**UTK Migration - CSV** parser and the Default Admin Set, inside the web container (local) or the
destination's web pod.  Then it waits for the entries and the relationship pass, checks every work
in the file against the repository (members, collection, thumbnail), and exits nonzero on anything
that does not match.  It asks before importing, and on prod asks you to type `prod`.

| Option | Effect |
| --- | --- |
| `--dev`, `--staging`, `--prod` | destination, as above; none means local |
| `--tenant CNAME` | required on staging and prod; local is `dev-utk-knapsack.localhost.direct`, dev is `demo.utk-knapsack-dev.notch8.cloud` |
| `--visibility V` | what work and collection rows with a blank `visibility` get, as on the form; default `open`. File set rows with none take their work's |
| `--email E` | the importer's owner; default `admin@example.com` |
| `--csv` | a regular CSV import instead: no `prepare_sheet`, the stock **CSV - Comma Separated Values** parser, files fetched from `remote_files` (below) |
| `--dry-run` | with `--csv`, run its checks and stop |
| `--again` | import a sheet whose name the tenant already imported in the last day; without it the import stops, so two runs of one sheet never overlap |
| `--yes`, `-y` | skip the confirmation prompt |

It needs a running worker and takes at least six minutes, since Bulkrax starts the relationship pass
only once no entry is still Pending, first checking five minutes after the entries are queued.

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
  collections they do not define.  Prepare them first with
  `bin/migration/prepare_collections tmp/migration/sheets/collections.csv`, which needs no AWS or
  kubectl: it collapses the role columns, adds `primary_identifier`, and stops on the same checks
  as a work sheet.

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
   property, or a controlled value its local vocabulary does not hold, is caught: the migration
   factory saves resources directly, with no validations.  Properties citing only remote
   authorities are not checked.
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
file set with no derivatives is usually correct; see `MIGRATION_PLAN.md`.  Step 4 lists, as a
warning rather than a stop, the ones legacy should have made derivatives for (an intermediate file,
or a file set of a `Pdf`), since the import has to generate them.

## Importing a regular CSV

A sheet of new files on remote URLs (`hykuimports.lib.utk.edu`) rather than records in legacy skips
`prepare_sheet` and goes straight to the destination from UTK's sheet:

```bash
bin/migration/import_sheet tmp/migration/sheets/collections_bakerav_replace.csv --prod \
  --tenant dc.utk-knapsack-production.notch8.cloud --email support@notch8.com --csv --dry-run
```

Before importing it stops on: duplicate rows; role columns (`creator`, `utk_composer`), which only
`prepare_sheet` converts to `creator_name_N`/`creator_role_N`; `https://pcdm.org` in `rdf_type`; a
missing required property; a file set with no `remote_files`; a remote file that is not 2xx or comes
back as an HTML page (islandora `datastream/OBJ` links answer with a bot check); a parent neither in
the sheet nor on the tenant; a file set whose parent is a collection rather than its work; and a file set already on the tenant, since Bulkrax's update path keeps
the old file.  Works already on the tenant are noted: the import updates their metadata.  A remote
file named in its folder's Apache listing passes without a fetch; the rest are fetched one by one, and
a 404 names any listed file that differs only by underscores, case or extension.

Imports into a deployed tenant wait for one of `IMPORT_SLOTS` (3) on this machine, and a second run
of the same sheet stops at once, so any number can be started together: each starts when a slot
frees.  The wait counts only the importer's own Bulkrax jobs, so one import's failures never fail
another's check.

After the import it checks each work holds the sheet's members and each file set has its parent, a
file, and is not an HTML page.  It does not check thumbnails, which come later from the derivative
jobs.

To replace files, list the file sets the sheet names that are already on the tenant, then delete
them and import:

```bash
bin/migration/delete_file_sets tmp/migration/sheets/<name>.csv --prod \
  --tenant dc.utk-knapsack-production.notch8.cloud --email support@notch8.com           # lists
bin/migration/delete_file_sets ... --apply                                               # deletes
```

It only touches a file set whose `source_identifier` matches exactly once and whose work is the
row's parent.

## Layout

```
bin/migration/
  prepare_sheet            the command
  import_sheet             imports its output, or a regular CSV with --csv
  delete_file_sets         lists, then deletes, a sheet's file sets already on a tenant
  lib/migration/
    options.rb             flags
    confirmation.rb        the prompt
    target.rb              local, dev, staging and prod presets
    sheet.rb               reading, slicing, finding a row's top-level work
    transform.rb           the import CSV
    preflight.rb           its stop lines: unmatched, missing required, no digest, unknown columns
    csv_preflight.rb       the --csv stop lines on the sheet itself
    remote_files.rb        checks remote files against folder listings, fetching the rest
    csv_check.rb           runs both, then checks the sheet against the tenant
    profile.rb             required properties and role columns, from the metadata profile
    originals.rb           step 3
    derivatives/           steps 4 and 5
    pod.rb                 runs a script in a pod over kubectl, or in the local web container
    pod/                   the scripts that run inside the pods; import.rb under rails runner
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
| `POD_TIMEOUT` | `1800` | seconds before a hung `kubectl exec` (lookup, stage, fill) is killed and tried once more; at most `1800`, since the retry reuses URLs signed for an hour |
| `IMPORT_SLOTS` | `3` | imports into one deployed tenant at once from this machine; more wait for a slot, since 5 at once restarted FITS and a prod web pod |
| `LEGACY_SLOTS` | `2` | `kubectl exec` calls into legacy at once, across every prepare on this machine; more waits for a slot, since 7 at once took legacy's web pods down |
