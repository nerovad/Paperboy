# OMS Historical Backfile Findings and Staging

## Purpose

This document records the files found under the parent of
`$P2M_DATARUNNER_ROOT` that appeared eligible for OMS preprocessing on or
after July 1, 2026, and describes the implemented safe staging workflow for
processing them exactly once through Data Runner.

The `$P2M_DATARUNNER_ROOT` subtree was excluded from the historical
scan.

## Matching criteria

The scan used the filename patterns defined by
`script/ruby/data_runner/orchestration/preprocess/oms.rb`:

- Marker: `Mail.dat_<8- or 9-digit OMS number>.zip`
- Companion: `<OMS number>-*.csv`
- Daily presort: `Presort Fields Export_<OMS number>.txt`
- Move results: `MoveResults_<OMS number>.txt`

A job was included when:

1. Its marker modification time was on or after `2026-07-01 00:00:00` in the
   local Pacific time zone.
2. At least one recognized input with the same OMS number existed in the
   marker's directory.

Archive directories were included. The marker modification time was used as
the occurrence date because the OMS number itself does not encode a date.

## Results

The scan found 61 unique OMS numbers:

```text
2026-07-01: 50506986, 50527576, 50384054
2026-07-02: 50530758, 48831394
2026-07-06: 50535308
2026-07-07: 50530672, 50532533
2026-07-08: 50530610
2026-07-09: 50693171
2026-07-10: 50601332, 50601351
2026-07-13: 50695430, 50755269, 50004445, 50831227
2026-07-14: 50826450
2026-07-15: 50837126, 50826475
2026-07-16: 50841078, 50897952
2026-07-20: 50841099, 50899655, 49926534, 50959114, 50903858,
            50995710
2026-07-21: 51007822
2026-07-23: 50902859
2026-07-24: 50906070, 50906089
2026-07-30: 51040469, 51040488, 51160451, 51033937
2026-07-31: 51175607
2026-08-04: 51241789, 51242411, 51285021, 49871847
2026-08-05: 51171039, 51171120
2026-08-06: 51421770
2026-08-07: 51285040
2026-08-10: 51484740, 51499910
2026-08-11: 51426712, 50983598, 51498914
2026-08-12: 51501733, 51502827, 51567285
2026-08-13: 51511999, 51577680, 51593022
2026-08-17: 51512024, 51579209, 51502810
2026-08-18: 51670317
2026-08-19: 51612841, 51572188
```

## Incomplete jobs

The preprocessor can generate only the outputs for inputs that exist.
However, the OMS orchestration declares Companions, Dailypresorts, and
Moveresults as children, and its output verification requires all three
generated CSV files before processing continues.

Five of the 61 jobs do not have all three input categories:

| OMS number | Missing input |
| --- | --- |
| 50004445 | Companion CSV |
| 50903858 | Companion CSV and MoveResults |
| 51033937 | MoveResults |
| 50983598 | Companion CSV |
| 51502810 | Companion CSV |

Therefore, 56 jobs appear processable by the current pipeline without
changing its completeness requirements. The five incomplete jobs require
source-file recovery or an explicit business decision to permit partial OMS
imports.

## Implemented backfile staging

The OMS orchestration root remains `$P2M_DATARUNNER_ROOT`. Historical source
files are discovered below its parent, while the normal OMS queue continues to
use the configured `P2M_STAGING` location. The staging and processed locations
are resolved by `P2m::Paths`, so they may be relative to the Data Runner root
or absolute FileStore/SMB locations.

`script/ruby/p2m/print_and_inserting_done.rb` implements the one-job-at-a-time
backfile stager. Its behavior is:

1. Recursively scan the configured source root, excluding the
   DataRunner subtree.
2. Apply the filename and cutoff criteria documented above.
3. Write a JSON report containing discovered files, associated-file counts,
   source directories, statuses, and details.
4. Classify jobs as `ready`, `incomplete`, `duplicate OMS number`,
   `duplicate marker`, or `duplicate input`.
5. Mark ready jobs as `staging conflict` when the same OMS number is already
   queued in the configured staging directory.
6. Skip processed OMS numbers and do not overwrite different destination
   files.
7. Copy the first ready job's recognized files into the configured staging
   directory, preserving metadata and refusing conflicting destinations.
8. Leave the marker with the other staged inputs; the normal OMS queue then
   validates, imports, and archives the job.

The stager copies the complete selected job as one operation from the
backfile source into the staging directory. The normal orchestration queue
uses the marker as its entry point only after the copy has completed.

The stager supports a scan-only mode through the Paperboy `Stage Data` screen.
The screen runs the scan and presents the report without staging. The normal
staging action writes the same report to:

```text
$P2M_DATARUNNER_ROOT/p2m_oms_backfill_report.json
```

After a successful import, the OMS postprocessor moves the staged inputs and
marker into:

```text
<configured processed path>/<OMS number>/
```

That directory and the OMS upload ledger are both used as idempotency and
state records. A later backfile run sees processed directories and reports a
duplicate OMS number. Normal UI staging also consults the ledger and rejects
an OMS whose import has already begun. This prevents a second import through
the normal staging path.
The historical source files can remain in place for audit and recovery.

The stager refuses to overwrite files with different size or modification
metadata. It marks a same-number queue conflict in the report and stages no
new job while the staging area already contains an OMS marker. This makes
interruption and restart behavior visible and avoids mixing jobs.

The report can be regenerated without staging with the Rails-backed service:

```ruby
P2m::PrintAndInsertingDone.scan(start_date:, end_date:)
```

The staging operation is invoked with `P2m::PrintAndInsertingDone.call` and
is run in `P2m::StageDataJob` for the UI workflow.

## Recommendation for incomplete jobs

Recover the missing source files for the five incomplete jobs before
processing them. The backfile stager reports incomplete jobs and does not copy
them. The OMS ledger and orchestration still require all three input datasets;
making orchestration children optional is not recommended because it would
also allow incomplete future jobs to pass without an error.

If partial historical imports are required, implement that as an explicit
backfile-only policy with a reviewed allowlist of OMS numbers. Do not weaken
the default OMS orchestration or ledger validation globally.

## Current implementation references

- `script/ruby/p2m/print_and_inserting_done.rb`
- `app/services/p2m/print_and_inserting_done.rb`
- `app/services/p2m/oms_upload_ledger.rb`
- `app/services/p2m/paths.rb`
- `app/controllers/p2m/stage_data_controller.rb`
- `app/jobs/p2m/stage_data_job.rb`
- `test/scripts/p2m_print_and_inserting_done_scan_test.rb`
- `test/scripts/p2m_print_and_inserting_done_test.rb`

## Proposed commit message

```text
Document OMS historical backfile staging

Record eligible OMS jobs and incomplete source sets.
Describe implemented staging, reporting, and duplicate safeguards.
```
