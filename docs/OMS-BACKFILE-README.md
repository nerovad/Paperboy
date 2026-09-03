# OMS Historical Backfile Findings and Recommendations

## Purpose

This document records the files found under the parent of
`$P2M_DATARUNNER_ROOT` that appear to
be eligible for OMS preprocessing on or after July 1, 2026, and recommends a
safe way to process them exactly once through Data Runner.

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

## Recommended backfile design

Keep the existing OMS orchestration root at `$P2M_DATARUNNER_ROOT`. Do not
point it at the variable's parent directory, because the preprocessor expects
a flat staging directory while the historical inputs are spread across
multiple output and archive directories.

Add a one-time historical backfile staging command with the following
behavior:

1. Recursively scan the parent of `$P2M_DATARUNNER_ROOT`, excluding the
   DataRunner subtree.
2. Apply the filename and cutoff criteria documented above.
3. Reject or report jobs that do not contain all required input categories.
4. Before staging an OMS number, check for
   `$P2M_DATARUNNER_ROOT/02_Processed/<OMS number>`.
5. Skip the job when that processed directory already exists.
6. Copy the recognized inputs for one OMS number into the DataRunner root.
7. Copy its `Mail.dat_<OMS number>.zip` marker into
   `DataRunner/00_SentToUSPS` last.
8. Let the existing queue drain and postprocessor complete before staging a
   conflicting job.

Publishing the marker last is important: the marker is the queue entry, so
the queue must not see a job until all of its inputs are staged.

After a successful import, the existing OMS postprocessor moves the staged
inputs and marker into:

```text
$P2M_DATARUNNER_ROOT/02_Processed/<OMS number>/
```

That directory should be treated as the durable idempotency record. A later
backfile run will see it and skip the OMS number, preventing a second import.
The historical source files can remain in place for audit and recovery.

The staging command should also stop rather than overwrite files when a
different or partially staged job is already present in the DataRunner root
or queue. This makes interruption and restart behavior visible and avoids
mixing jobs.

## Recommendation for incomplete jobs

Recover the missing source files for the five incomplete jobs before
processing them. Making orchestration children optional is not recommended
as part of the backfile because it would also allow incomplete future jobs
to pass without an error.

If partial historical imports are required, implement that as an explicit
backfile-only policy with a reviewed allowlist of OMS numbers. Do not weaken
the default OMS orchestration validation globally.

## Proposed commit message

```text
Document OMS historical backfile recommendations

Record eligible OMS jobs and incomplete source sets.
Describe idempotent staging and duplicate-processing safeguards.
```
