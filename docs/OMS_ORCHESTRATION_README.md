# OMS Data Runner Orchestration

## Overview

`config/data_runner/dsl/print_2_mail_billing_data/oms.rb` defines `Oms`, a
control-only Data Runner DSL
that coordinates three related datasets produced by an Output Management
System (OMS) print job. It does not define a source schema or database table
of its own. Instead, it selects one print job from a file-system queue,
preprocesses that job into normalized CSV inputs, runs three child DSLs, and
archives the source files after successful database injection. Paperboy also
records each staged OMS job in the `p2m_oms_uploads` ledger so validation,
import, archive, and failure state can be shown in the OMS Status screen.

The orchestrator belongs to the `print_2_mail_billing_data` group and is
enabled for both manual and scheduled execution. Its schedule frequency is
daily. Manual refreshes can select individual queued OMS numbers through the
Print 2 Mail refresh screen; scheduled refreshes drain the queue.

## Configuration

The DSL establishes the following directory contract:

| Configuration key | Resolved path | Purpose |
| --- | --- | --- |
| `root_path` | `$P2M_DATARUNNER_ROOT` | Parent for orchestration directories |
| `sent_path` | `$P2M_DATARUNNER_ROOT/$P2M_STAGING` | Complete-job queue |
| `output_path` | `$P2M_DATARUNNER_ROOT/$P2M_TEMPORARY_OUTPUT` | Preprocessed CSV output |
| `processed_path` | `$P2M_DATARUNNER_ROOT/$P2M_PROCESSED` | Per-OMS archive after injection |

`P2m::Paths` resolves relative locations against `P2M_DATARUNNER_ROOT` and
leaves absolute locations unchanged. The orchestration helper resolves the
same configuration for Data Runner. The symbolic queue path, `:sent_path`,
resolves to the absolute staging directory.

## Queue contract

A file is a queue entry only when its basename matches this anchored,
case-insensitive pattern:

```text
Mail.dat_<8- or 9-digit OMS number>.zip
```

Examples:

```text
Mail.dat_51572188.zip
Mail.dat_123456789.zip
```

Directory names, partial matches, OMS numbers shorter than eight digits,
and files with additional suffixes are not queue entries.

Queue entries are sorted lexicographically. A scheduled refresh processes the
first entry and repeats until no matching marker remains. A manual refresh can
set `DATARUNNER_QUEUE_OMS` to target one marker, and the refresh UI creates
one Data Runner group-run item per selected OMS number. Processing is serial;
only one OMS number is active during a queue iteration.

The marker is a control file. The preprocessor does not extract or read the
ZIP archive. It obtains the selected OMS number from the marker's filename
and finds corresponding source files in the same queued-job directory.

## Recognized source files

For the selected OMS number, preprocessing recognizes these basenames directly
in the configured staging directory:

| Dataset | Input pattern | Multiplicity |
| --- | --- | --- |
| Companions | `<OMS number>-<nonempty text>.csv` | Zero or more |
| Dailypresorts | `Presort Fields Export_<OMS number>.txt` | Zero or one |
| Moveresults | `MoveResults_<OMS number>.txt` | Zero or one |

Matching is anchored and case-insensitive. Only regular files directly inside
the staging directory are considered; preprocessing is not recursive. The
staging ledger additionally tracks production PDFs and postal reports as
associated original files, but those files are not converted into child CSV
outputs.

Multiple companion files are valid. They are read in filename order and
combined into one CSV. Every companion file must have the same header.
Multiple daily-presort or move-results files for one OMS number are rejected.

All three input categories are required. Preprocessing also requires equal
row counts, matching Presort and MoveResults record-ID sets, unique nonblank
AIMS mail-piece IDs, and a nonblank Budget 1 job ID for every companion row.

## Preprocessing

The preprocessing lifecycle invokes:

```text
script/ruby/data_runner/orchestration/preprocess/oms.rb
```

with these resolved arguments:

```text
SENT_PATH OUTPUT_PATH
```

The script performs the following work:

1. Selects the lexicographically first marker in `SENT_PATH`, or the marker
   named by `DATARUNNER_QUEUE_OMS`.
2. Extracts its OMS number.
3. Classifies matching files directly inside `SENT_PATH`.
4. Validates completeness, row identity, and companion headers.
5. Removes prior `companions.csv`, `dailypresorts.csv`, and
   `moveresults.csv` files from `OUTPUT_PATH`.
6. Writes the available outputs atomically.

The generated files are:

```text
01_TemporaryOutput/companions.csv
01_TemporaryOutput/dailypresorts.csv
01_TemporaryOutput/moveresults.csv
```

Each output receives `omsnumber`, `maildate`, and `importdatetime` metadata columns.
`maildate` is the preserved Mail.dat marker date used for duplicate detection.
`importdatetime` is the UTC time at which that OMS number is preprocessed.
Embedded line endings in field values are replaced with spaces.

Companion CSV input supports a UTF-8 byte-order mark. Its common header is
written once, followed by data from all companion files in filename order.
Daily-presort and move-results inputs are read as UTF-16LE, tab-delimited
text and serialized as standards-compliant CSV.

Output files are created through temporary files, flushed and synchronized,
then moved into place. A reader therefore does not see a partially written
individual output file.

## Child DSLs

The `children` list defines the processing order:

1. `Companions`
2. `Dailypresorts`
3. `Moveresults`

The child configurations map the generated CSV files to SQL Server:

| Child DSL | Local input | Destination |
| --- | --- | --- |
| `Companions` | `companions.csv` | `GSASQL16.GSABSS.dbo.companions` |
| `Dailypresorts` | `dailypresorts.csv` | `GSASQL16.GSABSS.dbo.daily_presorts` |
| `Moveresults` | `moveresults.csv` | `GSASQL16.GSABSS.dbo.move_results` |

All three database connections use append injection. The database table name
`daily_presorts` is reproduced exactly from the current child DSL.

The source locations declared by the child DSLs are not used to fetch the
OMS files during orchestration. Instead, the orchestrator copies each
preprocessed CSV into Data Runner's `01_Download` stage using the child's
`source.local` filename, then invokes the standard child transformations.

## Refresh lifecycle

The command-level operational entry point is:

```sh
bundle exec rake 'DataRunner:refresh[Oms]'
```

The Paperboy Print 2 Mail refresh screen uses the same Data Runner service and
queues a background group run. It previews queued markers as `OMS <number>`
entries, supports selecting a subset, and reconstructs pending OMS entries on
restart. The underlying job sets `DATARUNNER_QUEUE_OMS` for each selected OMS.

For every queued marker, refresh runs this lifecycle:

```text
Find next marker
  -> reject the OMS number when the processed archive already exists
  -> preprocess selected OMS inputs
  -> verify all three temporary CSV files
  -> copy CSV files into output/data_runner/01_Download
  -> run to_csv for each child
  -> verify normalized child files
  -> run use_dsl for each child
  -> verify DSL-applied child files
  -> append all three child datasets in one SQL Server transaction
  -> postprocess and archive the OMS job
  -> confirm that the queue marker was removed
  -> repeat
```

The scheduled step configuration contains `download`, `to_csv`, `use_dsl`,
and `inject`, which is the refresh sequence used for existing tables. Manual
configuration exposes the complete Data Runner step set, including schema
generation and table-management stages. Setup and one-shot operations run a
single orchestration lifecycle; unlike refresh, they do not drain the queue.

## Postprocessing and archive layout

Postprocessing invokes:

```text
script/ruby/data_runner/orchestration/postprocess/oms.rb
```

with these resolved arguments:

```text
SENT_PATH OUTPUT_PATH PROCESSED_PATH
```

After all child injections succeed, it creates this archive directory:

```text
<configured processed path>/<OMS number>/
```

It moves every original staged file for the selected OMS number into that
directory without rewriting its contents. An existing OMS archive is a
hard failure. It then removes the three temporary CSV outputs.

Moving the marker out of the configured staging directory acknowledges the
queue entry. The
queue-drain helper verifies this by checking that the same entry is no longer
first in the queue after the lifecycle finishes.

## Failure and restart behavior

Failures before postprocessing leave the queue marker in place, so a later
refresh selects the job again. The OMS ledger records validation, import, or
archive failure details when the tracked stages are running. Source and
diagnostic files also remain available for investigation. Temporary outputs
may exist, but preprocessing removes the three known output names before
rebuilding them on the next run.

All three child inserts share one transaction. Any child failure rolls back
the unit and leaves the complete queued job unchanged. Each child table
rejects an existing `omsnumber` during injection. A failure after commit but
before archival is recorded as an archive failure; the staged originals remain
available for investigation, while a retry is prevented by the existing
database rows and the processed-archive checks.

Duplicate detection uses the OMS number as its boundary. Staging rejects an
OMS number already represented by an archive or an upload whose import has
begun. Refresh repeats the archive check before preprocessing, and each child
table rejects an existing `omsnumber` inside the shared SQL transaction.

## Operational requirements

- Stage the complete job in the configured staging directory, including all companion files,
  Presort and MoveResults exports, postal reports, and the Mail.dat marker.
- Do not mix source files for different active jobs unless each basename
  contains the correct OMS number and each marker has a complete input set.
- Provide all three input categories for normal orchestrated refreshes.
- Keep no more than one daily-presort and one move-results file per OMS
  number.
- Ensure all companion files for an OMS number have identical headers.
- Do not manually remove a marker to acknowledge a job before successful
  injection and postprocessing.
- Before staging historical files, use the backfile report and check whether
  the OMS number already exists in the processed archive or the OMS ledger.

## Important implementation characteristics

- Queue and source discovery are non-recursive.
- Queue ordering is lexical by full marker path basename, which effectively
  orders equal-width OMS numbers numerically rather than by file date.
- The `Mail.dat` ZIP contents are not inspected. Its preserved modification
  date supplies the mailer date stored with each imported row.
- File matching is case-insensitive, but the selected OMS digits must match
  exactly across marker and source basenames.
- Companion output concatenation is deterministic because inputs are sorted.
- Database loading is append-only within one orchestrator-level transaction
  spanning all three child tables.
- Successful postprocessing is what removes the queue entry and permits the
  queue-drain loop to advance.

## Related implementation files

- `config/data_runner/dsl/print_2_mail_billing_data/oms.rb`
- `config/data_runner/dsl/print_2_mail_billing_data/companions.rb`
- `config/data_runner/dsl/print_2_mail_billing_data/dailypresorts.rb`
- `config/data_runner/dsl/print_2_mail_billing_data/moveresults.rb`
- `script/ruby/data_runner/helpers/orchestration_helpers.rb`
- `script/ruby/data_runner/orchestration/preprocess/oms.rb`
- `script/ruby/data_runner/orchestration/postprocess/oms.rb`
- `script/ruby/data_runner/constants/workflow.rb`
- `script/ruby/data_runner/constants/workflow_paths.rb`
- `app/services/p2m/paths.rb`
- `app/services/p2m/oms_upload_ledger.rb`
- `app/services/p2m/data_refresh.rb`
- `app/jobs/data_runner/group_refresh_job.rb`
- `script/ruby/p2m/print_and_inserting_done.rb`
