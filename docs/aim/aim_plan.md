# AIM Plan Of Attack

Date started: 2026-09-04
Branch: `AIM-AI-Review`
Companion documents: `docs/aim/aim_todo.md`, `docs/aim/aim_handoff.md`

Steps below cite findings as `audit C1`, `audit H8`, `audit M3` and so on.
Those come from a read-only review of the AIM backend carried out on
2026-09-03 against commit `4cd3012e`, published at:

<https://claude.ai/code/artifact/dd09c226-e94c-4dde-8432-36f8374ff350>

`C` findings are critical (silent data loss or wrong results), `H` are
high (blocking the approval phase), `M` are medium. The plan is ordered by
dependency rather than by severity, so the numbering does not run in order.

This is the working plan for finishing the AIM backend and then the user
approval side. It is deliberately written as a sequence of small steps that
are each edited, tested, and pushed on their own.

**If you are an AI assistant or a new developer picking this up: read the
Guardrails section below in full before you touch anything. It is not
boilerplate. It is the single most important part of this document.**

---

## Guardrails — Read First, Every Session

**AIM is a sub-component of PAPERBOY. It is not the whole application.**
Paperboy runs many other things — forms, billing, Print 2 Mail, Data
Runner, safety reporting, fleet, production — and they are in active use by
people who are not part of this project. Breaking any of them is a far worse
outcome than shipping an AIM feature slowly.

### The rule

**NEVER edit any part of Paperboy outside of AIM.**

Allowed without asking:

```text
app/controllers/aim/**          app/helpers/aim/**
app/controllers/concerns/aim/** app/models/aim/**
app/services/aim/**             app/views/aim/**
app/assets/stylesheets/pages/_aim_*.scss
test/**/aim/**                  script/python/aim/**
docs/aim/**                     db/migrate/** (new files only)
```

### The one exception

Shared configuration — things like `config/routes.rb`,
`config/database.yml`, `config/initializers/*`, `db/schema.rb`, `Gemfile`,
`app/javascript/controllers/index.js`, `app/services/pfa/work/registry.rb`
— may sometimes need a change for AIM to work at all.

When that happens:

1. **Stop.**
2. **Show Joshua the exact diff and explain why AIM cannot work without it.**
3. **Wait for explicit approval.**
4. Only then make the change.

Approval for one shared-config change is **not** approval for the next one.
Ask every time.

### How shared-config changes must be shaped

- **Additive only.** Add a new table; never `ALTER` an existing one. Add a
  new route inside the `aim` namespace; never modify an existing route. Add
  a new initializer key; never repurpose an existing one.
- **Never modify an existing model, service, or controller outside AIM**,
  even a one-line change, without going through the approval step above.
- `db/schema.rb` is only ever touched as regenerated output of a new AIM
  migration — never hand-edited.

### No hardcoded paths. No hardcoded credentials. Ever.

Every filesystem path, share name, server name, database name, user name
and password comes from an environment variable. None of them are ever
written as a literal in Ruby, Python, ERB, a rake task, a `.bat` file or a
test.

This is not style. Everyone working on Paperboy has a different local
setup, and a literal path is a path that works on exactly one machine.

**Not allowed:**

```python
AI_QUEUE_DIR = os.path.join(os.path.dirname(SQL_QUEUE_DIR), "_AI_QUEUE")
folder_path  = f"\\AIM\\00 INBOX\\{bu_number}"
conn_str     = "DRIVER={ODBC Driver 17 for SQL Server};...;Encrypt=no;"
```

```ruby
DEFAULT_ALIAS_FILE = Rails.root.join('script/python/aim/vendor_aliases.json')
def rejected_dir = path_for(:rejected) || queue_base_child('_REJECTED')
```

**Allowed:**

```python
AI_QUEUE_DIR = env('AIM_AI_QUEUE_DIR')
```

```ruby
def rejected_dir = path_for(:rejected)
```

A missing variable must never silently fall back to a guessed path — a
wrong guess is how invoices end up in a folder nobody is watching. But
*where* it fails differs, and getting this wrong would break Paperboy for
everyone:

- **Python workers: fail at startup**, with a message naming the variable.
  They are dedicated processes; refusing to start is correct.
- **Rails: fail at the point of use, never at boot.** A missing AIM
  variable must surface as an AIM screen reporting the queue is not
  configured. It must *never* raise during application boot, because that
  would take down Billing, Forms and Print 2 Mail along with AIM.
- **Tests: never read the real environment at all.** AIM tests inject their
  own configuration and point at a temp directory. This is what keeps a
  teammate's `rake test` green when they have not yet pulled LockBox.

The same applies to anything else environment-specific: the ODBC driver
name, the Ollama model names, and the Laserfiche import folder are all
configuration, not constants. Model names especially, since the move to a
GPU server will change them.

**The rule has exactly two exceptions. Both are written down here; there
are no others.**

1. **The `.bat` launchers in `script/python/aim/` are out of scope.**
   Decided by Joshua, 2026-09-08. Their only job is to start a worker on
   the server — `python 00_Ingestion_Watcher.py` and nothing more. They
   are the thing being launched *by* the environment rather than code that
   reads configuration, so a path inside one is not the failure this rule
   exists to prevent. Do not rewrite them to read variables.

2. **Finding the `.env` file itself.** `env_file_candidates()` in
   `pipeline_common.py` has to know somewhere to look before any variable
   is readable — configuration cannot say where configuration lives.
   Keep that seed as small as possible: `AIM_ENV_FILE` first, then the
   script's own directory. Nothing else; the `cwd` and parent-directory
   guesses are removed in step 0.6.

Everything else — every `.py`, `.rb`, `.erb`, rake task and test — obeys
the rule with no fallbacks at all.

Credentials additionally must never be printed, logged, echoed into a
terminal, or committed. Reading them from the environment to open a
connection is fine; showing their values is not.

**The test of whether this has been done right: moving to a different
database server must be a LockBox edit and nothing else.** Paperboy runs
on `GSASQL16` today and is planned to migrate fully to `gsa-sql22` soon.
When that happens, no AIM code should need to change — only variable
values.

That rules out more than it first appears:

- No server, instance, database, port, user or password literal anywhere.
- **No hardcoded port.** `gsa-sql22\gsasql22` is a named instance on a
  dynamic port — it answered on 58026, and that number can change when SQL
  Server restarts. Ask the SQL Browser service on UDP 1434 for it, or read
  it from a variable. Never bake in 58026.
- **No hardcoded ODBC driver or encryption setting.**
  `pipeline_common.py:227` currently pins `ODBC Driver 17 for SQL Server`
  and `Encrypt=no`. Both are properties of the server being talked to, and
  both are likely to differ on SQL Server 2022.
- No assumption that Rails and the Python workers share a server, or that
  AIM's tables live in the same database as Paperboy's.

### Changing LockBox

`~/gitea/LockBox` (`git@gsa-gitea:BSS/LockBox.git`) is the definition point
for all Paperboy environment variables. The repo `.env` is a copy of
`LockBox/Paperboy.env`; mount points come from
`LockBox/Paperboy-wsl2-fstab`.

**LockBox is shared across every Paperboy work area, and it is handled
differently from normal code.** Other developers do not receive changes
automatically — they have to pull LockBox by hand and refresh their local
`.env`. Adding a variable therefore breaks other people's environments
until they do that.

**Work on a LockBox branch.** LockBox is an ordinary git repository we hold
locally, so AIM variables are developed on a branch and only reach anyone
else when that branch is merged and pushed. Nobody is disturbed in the
meantime.

```bash
cd ~/gitea/LockBox
git checkout -b aim-config          # once, at the start of Phase 0
# add AIM variables to Paperboy.env, commit on the branch
```

While the branch is unmerged, keep the repo `.env` in step with it by
copying `LockBox/Paperboy.env` over `Paperboy/.env` as usual. Development
and testing proceed normally.

**Never push and never merge LockBox. Commit locally and stop.**

An assistant may create the `aim-config` branch, edit `Paperboy.env` on it,
and commit there. That is the end of it. Clarified by Joshua 2026-09-08,
superseding an earlier note that said pushing the branch was fine:

> we manually DOWNLOAD the lockbox repo. I will manually PUSH it once we
> have my local copy updated, and then I will let the others know the AIM
> parts have been updated.

So the whole distribution half belongs to Joshua: **he** pushes, **he**
decides when it merges, **he** notifies the team, and they then download
the new copy by hand. LockBox reaches other people only through that
sequence, and the timing is a coordination problem with his coworkers
rather than a code one.

Report that the local commit is ready and leave it. Do not run
`git push` or `git merge` in LockBox, and do not ask for permission to —
just say it is ready.

To add or change an AIM variable:

1. Add it to `Paperboy.env` on the `aim-config` branch and commit there.
2. Copy the file to the Paperboy repo `.env` and carry on working.
3. Tell Joshua the local commit is ready, and stop. **He** pushes and
   merges it, **before** any AIM code that requires the variable is
   pushed.
4. **Joshua notifies the other Paperboy developers** that LockBox changed
   and they need to pull it and refresh their `.env`.
5. Only then does the AIM code get pushed.

Batch variable additions so the team is interrupted once per phase rather
than once per step. The branch is what makes batching easy — variables can
accumulate on it for as long as the phase takes.

Because AIM tests never read the real environment (see *No hardcoded
paths*), a developer who has not yet pulled LockBox still gets a green
suite. The notification is "pull LockBox before you next run AIM", not
"your build is broken".

> **Confirm this process.** The above is recorded from Joshua's
> understanding of what he was told. Before the first LockBox change,
> confirm the exact expectation with whoever owns that repo — particularly
> who needs notifying and how.

### Proving no harm was done

The promise is not enough. The proof is the test suite:

- Run the full suite **before** starting a step and record the result.
- Run it **again after**, and confirm the same tests pass.
- A step that turns any previously-passing test red is not finished,
  regardless of whether the failure looks related to AIM.

### Naming

Everything AIM creates is AIM-branded and namespaced: `aim_*` tables,
`Aim::*` models and services, `aim/` view and controller directories. Do not
create generic, un-namespaced "Paperboy things" on AIM's behalf.

### When in doubt

Stop and ask Joshua. A blocked step is cheap. A regression in Billing or
Print 2 Mail is not.

---

## Goal

Move Automated Invoice Management off Psigen Capture and Fusion and into
Paperboy, so it shares Paperboy's single sign-on and access control.

The end state, in order of delivery:

1. **Backend complete.** Invoices are ingested, read by the local vision
   model, routed through exception queues that staff can fully work inside
   Paperboy, and emitted with clean, typed metadata.
2. **User review.** A queue scoped by Budget Unit where assigned users
   approve invoices, edit metadata, and write notes.
3. **Fiscal handoff.** Approved data continues to the fiscal team.

Laserfiche is the system of record for the finished document. Docushare is
the legacy system being retired.

---

## How We Work

Every step below is a self-contained unit of work:

1. **Edit** only what the step names.
2. **Test** — add or update the tests the step names, then run the full CI
   gate locally (see below).
3. **If tests fail, keep editing until they pass.** Do not move to the next
   step with a red suite.
4. **Push** once green.

One step, one commit. If a step turns out to be bigger than it looks, split
it rather than growing it.

### The CI gate

All four must pass before a push:

```bash
bundle exec rubocop
bundle exec brakeman
bundle exec bundle-audit check
bundle exec rake test
```

For steps that touch `script/python/aim/`, also:

```bash
~/.venvs/aim/bin/pytest test/python/aim
```

That venv is built once, outside the repo:

```bash
python3 -m venv ~/.venvs/aim
~/.venvs/aim/bin/pip install pytest -r script/python/aim/requirements.txt
```

**This one is local only, and deliberately so.** `.github/workflows/ci.yml`
is not changed. Decided 2026-09-08: adding a Python step there would slow
every Billing, Forms and Print 2 Mail pull request and could fail them over
a Python install problem their authors never touched -- real cost to people
who get no benefit. AIM is the only area with Python workers and nobody else
edits them, so the check would almost only ever catch AIM's own mistakes,
which running the command above already does. If that changes, the fallback
is a path-filtered CI step that runs only when `script/python/aim/**` or
`test/python/aim/**` changed, so other teams' PRs skip it.

### Commit message format

**Say what was done, and stop.** 30 words or less, signed
`authored by claude` — no `Co-Authored-By` trailer and no session URL. This
is Joshua's standing instruction and it overrides any default attribution an
assistant is otherwise told to use.

Usually that is a subject line and the sign-off, nothing more. Reference the
step number, keep the subject inside 72 characters.

```text
AIM 1.1: raise when a SQL payload maps to no columns

authored by claude
```

Do not explain the reasoning, the symptom or the numbers in the commit. All
of that belongs in this document. Add a body line only when the subject
genuinely cannot carry the change, and keep it to one line.

### Before every step

Re-read `## Guardrails — Read First, Every Session` at the top of this
document. In short, and without replacing what that section says:

- AIM code only. Anything outside it is proposed to Joshua as a diff and
  waits for explicit approval, every time.
- Additive only. New tables, never `ALTER`. New routes in the `aim`
  namespace, never edits to existing ones.
- Full suite green before and after. A step that reddens an unrelated test
  is not finished.

### Branching

One branch per phase, named `aim/phase-N-slug`, cut from `master`:

```bash
git checkout master && git pull
git checkout -b aim/phase-0-config
```

Each step is one commit pushed to that branch as it lands, so there is
always a green remote checkpoint. When every step in the phase is done and
the suite is green, merge the phase branch to `master`.

`AIM-AI-Review` is the review branch this plan was written on. It carries
no unique commits and is not where the work happens.

### Ending a step, and handing off

Joshua runs `/clear` between steps, so each session starts with no memory
of the last one. **This document is the memory.** Keeping it current is
part of finishing a step, not an optional extra.

When a step's tests pass and the commit is pushed:

1. Tick the step's checkbox in this document.
2. Add a row to the Progress Log at the bottom.
3. Record anything the next session needs that is not already written down
   — a surprise, a decision made mid-step, a thing that turned out to be
   wrong. Put it in the step's entry or in Open Questions.
4. Commit those edits to this document too.
5. **Give Joshua a handoff prompt to paste into the next session.**

The handoff prompt should be short, and it should keep the next session
cheap. It does not re-explain the project — this document does that — and
it does not ask for the whole document to be read, because the later
phases are not needed yet:

```text
Read docs/aim/aim_plan.md before doing anything: the Guardrails, How We
Work, Environment Reference and Decisions sections in full, plus Phase 0.
Skip the later phases.

Branch: aim/phase-0-config
Last completed: step 0.3, pushed as <short sha>
Next: step 0.4
Notes: <anything unusual, or "none">

Confirm you have read the guardrails, then start the next step.
```

That is roughly a third of this document rather than all of it, and it is
everything a session needs to work one step correctly.

If the next step begins a new phase, say so and include the branch to cut:

```text
Next: step 1.1, which starts Phase 1. Cut a new branch aim/phase-1-dataloss
from master first. Phase 0 is merged.
```

---

## Environment Reference

Recorded here so nobody has to rediscover it.

### Paths

| What | Value |
|---|---|
| AIM share (WSL) | `/mnt/a` — from `A:`, see `LockBox/Paperboy-wsl2-fstab` |
| AIM share (Windows) | `E:\AIM` on GSA-SCAN02 |
| Worker environment file | `/mnt/a/_PROGRAM/.env` |
| Paperboy environment file | repo `.env`, from `LockBox/Paperboy.env` |
| Queue folders | `/mnt/a/_BACK_END/` |
| Watch tree | `/mnt/a/Invoices/<BU>/<Submitter>/` |

`/mnt/gsa-scan02-AIM` and `/mnt/gsa-scan02` are stale mount points and are
empty. Do not use them.

### How configuration reaches the workers

**GSA-SCAN02 has no git checkout. It never sees LockBox.** The workers read
a copy of the environment file that sits on the share next to them:

```text
LockBox/Paperboy.env  ->  repo .env  ->  /mnt/a/_PROGRAM/.env  ->  workers
   git, shared           git-ignored      copy on the share      read at import
```

`pipeline_common.py` searches for `.env` beside the script
(`env_file_candidates`), and the workers are installed in `_PROGRAM`
alongside it, so that copy is what they actually run on.

**That third hop was manual and had already drifted.** As of 2026-09-04 the
repo `.env` defined `AIM_AI_QUEUE_DIR` and the share `.env` did not —
exactly the variable at the centre of the `pipeline_common.py:109` bug. A
code fix alone would have reviewed clean, passed tests, and changed nothing
in production. `_PROGRAM/.env.before-lockbox` is the fossil of the last
hand copy.

**Step 0.7 closes the hop:** `bin/deploy-aim-workers` ships code and config
together, extracting only the `AIM_*` subset. Until that step lands, adding
a variable to LockBox does nothing for the workers, so no Python step that
depends on a new variable can be verified on GSA-SCAN02 before 0.7.

The share copy is currently the *whole* Paperboy environment, including
`ENTRA_ID_CLIENT_SECRET` and `POSTGRES_PASSWORD`, on a share readable by
anyone who can reach `E:\AIM`. The workers need only the `AIM_*` set.
Extracting the subset in 0.7 stops this recurring; cleaning up the existing
file is Joshua's call and is not AIM's to do unasked.

### Budget Units seen in the watch tree

`0000`, `4601`, `4621`, `4641`, `4701`, `4703`, `4721` — four-digit codes.

### SQL — two servers

AIM spans both. This is the current state, not a transitional accident.

| | AIM data | Paperboy data |
|---|---|---|
| Server | `gsa-sql22\gsasql22` | `GSASQL16` |
| Version | SQL Server 2022 (16.0.1000.6) | — |
| Host | `gsa-sql22` (10.135.204.103) | `GSASQL16` (10.135.204.161) |
| Port | **58026** — 1433 is closed | 1433 |
| Database | `GSA_Scan` | `Paperboy_Dev` / `_Test` / `_Prod`, `GSABSS` |
| Test database | `AIM_Test` (Phase 5) | `Paperboy_Test` |
| Tables | `Aim_Invoices`, `Aim_Processing_Logs`, `Aim_Vendor_Aliases` | — |
| Read by | Python workers, and Rails once connected | Rails |

`AIM_Test` is ours and is where the new `aim_*` tables are tested.
`Paperboy_Test` is Rails framework plumbing shared by the whole
application — see step 0.1.

`gsa-sql22\gsasql22` is a **named instance on a dynamic port**. 58026 is
what it answered on, and it can change when SQL Server restarts. Ask the
SQL Browser service on UDP 1434 rather than hardcoding it.

Paperboy is planned to migrate fully to `gsa-sql22`. See
`## Decisions Already Made`.

### Existing table facts that matter

- `Aim_Invoices` already carries the whole chart-of-accounts field set, all
  currently empty: `BDO_DO_CT`, `Program_Number`, `Major_Program`, `Fund`,
  `Object`, `Program`, `Activity`, `Function`, `Phase`, `Department`. This
  is what the vendor/BU lookup is meant to populate.
- `Aim_Invoices` also already has `To_reviewers`, `Approved By`,
  `Invoice Status`, `Task` and `Credit Amount`.
- `Fusion Queue` is dead Psigen legacy.
- Almost every column is `nvarchar(max)`, including all money fields.
- `Aim_Processing_Logs.InvoiceConcatID` is a **computed column**:

  ```sql
  isnull(VendorName,    'UNKNOWN') + '.' +
  isnull(InvoiceNumber, 'UNKNOWN') + '.' +
  isnull(InvoiceTotal,  '0.00')    + '.' +
  isnull(CONVERT(nvarchar(10), InvoiceDate, 120), '1900-01-01')
  ```

  That is the correct four-field business key. It has **no unique index**,
  so it currently prevents nothing. `Aim_Invoices` has no equivalent column
  at all.
- The JSON payloads use the name `InvoiceConcatID` for something completely
  different — the folder/processing id. Two concepts, one name. The plan
  separates them as `batch_id` and `business_key`.
- `Aim_Vendor_Aliases` has 907 rows; `vendor_aliases.json` has 904 keys.
  The two stores have already diverged.

---

## Decisions Already Made

Recorded so they are not relitigated.

- **Architecture.** AIM stays in Paperboy. The workflow does not move into
  Laserfiche. The restructure is to stop using the filesystem as the state
  store, not to change platform.
- **Document types.** `Invoice`, `Memo`, `Credit`, `Coupon`, `Unknown`. All
  types flow through the same queues. Type dictates terminal behaviour only.
  Type-specific queue bypass is out of scope for now.
- **Duplicate key.** Same invoice number, same vendor, same amount, same
  date. Budget Unit is deliberately excluded, so the same invoice submitted
  under two BUs is caught.
- **Duplicate policy.** Exact four-field match is a hard block at the final
  gate before Fiscal. Vendor plus invoice number matching, with a differing
  amount or date, is surfaced to the reviewer as a possible duplicate but
  not blocked.
- **Approval routing.** Users get access to a BU queue. Invoices can sit
  unassigned in the shared BU queue, or be assigned to a named person.
  Assignment is source-agnostic so a scan coversheet barcode can set it
  later without redesign.
- **Vendor master.** Fiscal's annual CSVs seed the canonical vendor list.
  Vendors not covered by those CSVs are flagged provisional rather than
  silently invented.
- **Vendor CSV import.** A rake task plus a small AIM admin upload page. Not
  Data Runner — the files arrive once a year.
- **Laserfiche** is the target repository. Docushare is being retired.
- `aimusers` / `GSABSS.dbo.aimusers` is **not** in scope and is not the
  source for BU access.
- **Database placement (settles step 5.1).** The new AIM tables live in
  `GSA_Scan` on `gsa-sql22`, alongside the AIM tables that are already
  there. Not in the Paperboy database. The Python workers already connect
  to that server, so this removes the cross-server problem rather than
  creating one.
- **Two servers, today.** Paperboy's own databases are on `GSASQL16`; the
  AIM tables are already on `gsa-sql22`. AIM therefore needs a second
  Rails connection from the start — this is a current requirement, not a
  future one.
- **Full migration to `gsa-sql22` is planned.** Paperboy will move off
  `GSASQL16` soon. Until then use `GSASQL16` where Paperboy's own data is
  concerned. When the migration happens it must be a LockBox variable
  change and nothing else — see `## Guardrails → No hardcoded paths`.
  Driving Paperboy's migration is not AIM's job; being ready for it is.

---

## Phase 0 — Configuration Hygiene And Verification

**This phase comes first and nothing starts before it is finished.**

The point is to fix the configuration protocol *before* writing new code,
so later phases never add another hardcoded path that has to be corrected
later. After Phase 0 this is not work any more — it is just a protocol that
gets maintained, and step 0.8 makes the suite enforce it automatically.

Steps 0.1, 0.4 and 0.5 are tooling rather than config work. They are here
because there is no way to prove a configuration change is safe without
them.

- [x] **0.1 Create the `Paperboy_Test` database.** An empty database on
  `GSASQL16`, named by `PAPERBOY_TEST_DATABASE`. Then `bin/rails
  db:test:prepare` to load `db/schema.rb` into it.
  *Test:* `bundle exec rake test` runs to completion. Record the baseline
  pass/fail count in the Progress Log. No code changes in this step.

  **What this is, because it is easy to misread as an AIM thing.**
  `Paperboy_Test` is Rails framework plumbing, not an AIM artifact. When
  `rake test` runs, Rails boots the whole application and connects to the
  database `config/database.yml` names for the `test` environment. Every
  test in Paperboy uses it — Billing's, Forms', P2M's and AIM's. It is
  wiped and rebuilt from `db/schema.rb` on every run and holds no real
  data.

  It should already exist and does not, which is a pre-existing gap
  unrelated to AIM. Without it **no AIM test can run at all** — even
  `test/services/aim_vendor_alias_service_test.rb`, which only reads a
  JSON file, fails with `ActiveRecord::NoDatabaseError` because
  `test_helper.rb` boots Rails first. Without it there is no "edit, test,
  push" — only "edit, push, hope".

  AIM tests do write scratch fixture rows there (test users, groups and
  sessions, so a controller test can sign in). No AIM production data ever
  lives in it. **AIM's own tables are tested in `AIM_Test` on `gsa-sql22`,
  created in Phase 5.**

  Do not rename `Paperboy_Test` to something AIM-branded. It holds all 113
  migrations' worth of Paperboy tables, and the name comes from shared
  config that every other developer's test run depends on.

  **Done 2026-09-04. Baseline: 537 runs, 324 pass, 60 failures, 153
  errors, 0 skips** (serial). **Superseded 2026-09-08** — the phase branch
  was cut from a master 15 commits newer, where the suite is 544 runs, 333
  pass, 59 failures, 152 errors. Compare against that. The suite now runs to completion, which was
  the point of the step. It is not green, and none of the red is AIM's —
  see `## Open Questions → Pre-existing suite failures`.

  **What it took, beyond the plan.** `db:test:prepare` purges by *dropping*
  the database and recreating it, so the `GSAETL` login needs the
  server-level `GRANT CREATE ANY DATABASE`, not just `db_owner` on
  `Paperboy_Test`. Without it the drop succeeds and the recreate fails,
  leaving no database at all. `GRANT CREATE DATABASE` in `master` is the
  wrong spelling — it needs a `master` user, and `GSAETL` is a login.
  Rails re-creates the database on every schema change, so this is not a
  one-time setup.

  **Run the suite serially — `PARALLEL_WORKERS=1 bundle exec rake test`.**
  `test_helper.rb` calls `parallelize(workers: :number_of_processors)`,
  which on this workstation spawns 22 workers and 22 `Paperboy_Test-N`
  databases on GSASQL16. In parallel the run is nondeterministic and
  mostly bogus: fixture teardown truncates FK-referenced tables, which
  SQL Server refuses, so every test errors with
  `Cannot truncate table 'active_storage_blobs'`. Two consecutive parallel
  runs gave 149 and 537 errors. Serial is stable and is the number to
  compare against.

  **`rake test` dirties the working tree.** `DslGroupUpdaterTest` edits the
  real `config/data_runner/dsl/*.rb` rather than fixtures, rewriting the
  group name in 22 files. Always `git status` after a suite run and
  `git checkout -- config/data_runner/dsl/` before committing.

- [x] **0.2 Inventory every hardcoded path and credential, and add the
  missing variables to a LockBox branch.** Produce the full list first,
  agree the variable names, then `git checkout -b aim-config` in LockBox
  and add them there. The branch stays unmerged until Phase 0 is finished,
  so nobody else is disturbed while the work is in progress. Joshua pushes,
  merges and notifies once, at the end of the phase — an assistant never
  pushes or merges LockBox, see `## Guardrails → Changing LockBox`.
  Known additions needed: `AIM_AI_QUEUE_DIR` for the workers (Rails already
  reads it, Python ignores it), `AIM_ERROR_QUEUE_DIR`,
  `AIM_SPOOL_STATE_DIR`, `AIM_READY_TO_SPLIT_DIR` for Rails,
  `AIM_LASERFICHE_INBOX_PATH`, `AIM_ODBC_DRIVER`, `AIM_ODBC_ENCRYPT`,
  `AIM_VISION_MODEL`, `AIM_TEXT_MODEL`.
  *Test:* none — configuration only. Verify by diffing the variable names
  the code reads against the names LockBox defines.

- [x] **0.3 Remove hardcoded paths from the AIM Ruby.** Every fallback that
  guesses a folder name becomes a required variable that fails loudly when
  missing. This also fixes the audit M3 inconsistency where `path_for` and
  the `*_dir` readers disagree, so the sidebar reports "not configured"
  while writes still succeed.
  Targets: `invoice_directory_service.rb` lines 50, 56-59, 62
  (`queue_base_child` fallbacks); `vendor_alias_service.rb` line 7
  (`Rails.root.join`), lines 86 and 95 (`_PROGRAM`, `vendor_aliases.json`).
  *Test:* a missing variable raises a named error; `path_for` and the
  matching `*_dir` reader return the same value for every queue.

  **Done 2026-09-08.** `Aim::MissingConfiguration` (new, in
  `app/services/aim/missing_configuration.rb`) is raised at the point of
  use, never at boot. The service now has two readers and the split is the
  point: `path_for` is lenient and returns nil so the sidebar can say "not
  configured", while `path_for!` raises naming the variable and is what
  every `*_dir` reader calls. That fixes audit M3 — the two used to
  disagree, so the sidebar reported "not configured" while writes still
  landed in a guessed folder. `queue_base_child` is deleted outright, and
  `PATH_ENV` now carries `ai_queue` and `manual_processing` instead of
  special-casing them.

  In `VendorAliasService`, `DEFAULT_ALIAS_FILE` is gone and a bare
  `AIM_ALIAS_DB_FILE` filename now resolves against `AIM_PROGRAM_DIR`
  rather than a guessed `_PROGRAM`. One existing test asserted the old
  guess as correct behaviour and was inverted into a regression test.

  Suite 544 -> 552 runs, 333 -> 341 passing, failures and errors unchanged
  at 59/152. rubocop clean. Brakeman's 2 warnings and bundle-audit's
  findings are pre-existing on master and touch no AIM file.

- [x] **0.4 Make `pipeline_common.py` importable without side effects.**
  Today importing it pip-installs packages, plants Windows shortcuts,
  creates directories, and runs a full SQL alias sync. Move all of that
  behind an explicit `bootstrap()` call invoked from each worker's
  `__main__`. This is what makes every later Python step testable.
  *Test:* a new test imports the module with a temp environment and asserts
  no directories were created and no network calls attempted.

  **Done 2026-09-08.** Import is now pure. `bootstrap()` holds the
  directory creation, the `pytesseract` command assignment, the `.lnk`
  shortcut planting and the bi-directional SQL alias sync (a bare
  `get_vendor_aliases()` used to run at module scope, opening a database
  connection on import). Each worker calls `bootstrap()` from its own
  `__main__`.

  **`install_prerequisites()` is deleted rather than moved.** A bootstrap
  cannot install packages the module already needs at import, so
  dependencies belong to deployment: `script/python/aim/requirements.txt`
  carries all eleven, and step 0.7 installs them. `pywin32` is marked
  `sys_platform == "win32"` -- it is Windows-only and cannot install on
  Linux, which is why it could never have been a runtime install anyway.
  `create_windows_shortcut` already imports it lazily and tolerates its
  absence.

  **Test environment.** The workstation had none of the worker
  dependencies and no pytest. The venv lives at `~/.venvs/aim`, outside the
  repo deliberately: `.gitignore` has no venv entry and it is not an AIM
  file, so putting it in-tree would have needed a shared-config approval
  for something incidental. Create it with
  `python3 -m venv ~/.venvs/aim && ~/.venvs/aim/bin/pip install pytest -r
  script/python/aim/requirements.txt`, then run
  `~/.venvs/aim/bin/pytest test/python/aim`.

  **What these tests do and do not cover.** They assert that importing
  creates no directory, opens no socket and shells out to no pip, and that
  `bootstrap()` is what builds the queue tree. No Ollama, no SQL, no
  Windows, no invoice. Anything involving the vision model, real ODBC or
  Tesseract stays a manual check on GSA-SCAN02 after deployment -- the
  point of local tests is to tell routing bugs from model behaviour, not to
  prove the model works.

- [x] **0.5 Stand up the Python test harness.** `pytest`, a fixture that
  builds a fake queue tree in a temp directory, and a fake environment. No
  Windows, no Ollama, no SQL required.
  *Test:* the harness runs green in CI with one trivial test.

  **Done 2026-09-08, except the CI wiring, which needs approval.**
  `test/python/aim/conftest.py` provides four fixtures:
  `no_real_environment` (autouse -- strips every `AIM_*` variable so a real
  `.env` cannot change a result), `fake_environment` (a full configuration
  in `tmp_path`, creating nothing on disk), `pipeline` (the module imported
  against it) and `queue_tree` (the same with every directory created, plus
  `add_invoice()` for staging an invoice folder the way the watcher would).
  Nine tests pass: `~/.venvs/aim/bin/pytest test/python/aim`.

  **CI is deliberately not changed.** The pytest command is a local gate
  step; see `## How We Work -> The CI gate`.

- [x] **0.6 Remove hardcoded paths and connection literals from the AIM
  Python.**

  **Change `env()` to take a name and nothing else.** Today the signature
  is `env(name, fallback=None)`, and the fallback parameter is what makes
  every violation below possible and invisible to review. With it gone, a
  missing variable can only exit with a message naming it, and step 0.8's
  guard mostly reduces to "nobody added the parameter back". Do this
  first; the call sites then fail loudly until each is fixed.

  **All eight fallbacks go** (inventoried 2026-09-08 — the last five were
  first dismissed as "just filenames", which is the same violation):
  `pipeline_common.py:95` `_SQL_FAILED`, `:110` `_ERROR_QUEUE`, `:120`
  `Split_Invoices`, `:128` `pipeline_log.csv`, `:132`
  `vendor_aliases.json`, `:139` `vendor_rules.json`, `:146`
  `field_aliases.json`, and `07_benchmark_models.py:43`
  `E:\AIM\Invoices`.

  Other targets: `pipeline_common.py:109` (`_AI_QUEUE`, currently not
  configurable at all), `:227` (ODBC driver name and `Encrypt=no`), `:240`
  (mapping files resolved against `os.path.dirname(__file__)` — use
  `AIM_PROGRAM_DIR`), `:730` (the `\AIM\00 INBOX\` Laserfiche path),
  `:656` and the six model names in `01_AI_Extraction_Worker.py`;
  `00_Ingestion_Watcher.py:13` (`_SPOOL_STATE`);
  `07_benchmark_models.py:10-11`. Also narrow `env_file_candidates()` to
  the two entries allowed by `## Guardrails` exception 2.

  **Pin every new variable to the value the code derives today**, so this
  is a pure refactor with no behaviour change. Verified 2026-09-04: the
  derived `_AI_QUEUE`, `_ERROR_QUEUE` and `_SPOOL_STATE` paths all exist
  on the share and are in use, and the derived AI queue path is byte-identical
  to what the repo `.env` already declares. If a path is wrong, that is a
  separate finding, fixed by a LockBox edit rather than a code change.

  The `.bat` launchers are out of scope — see `## Guardrails`.
  *Test:* importing with a variable unset fails with a message naming it;
  the fake-tree fixture drives every path from the fake environment.

  **Done 2026-09-08.** `env()` now takes a name and nothing else, so a
  fallback cannot be added without changing the signature. All eight
  fallbacks are gone, `AI_QUEUE_DIR` reads `AIM_AI_QUEUE_DIR` instead of
  deriving it from `SQL_QUEUE_DIR`'s parent, the ODBC driver and encryption
  come from `AIM_ODBC_DRIVER`/`AIM_ODBC_ENCRYPT`, the six model names read
  `AIM_TEXT_MODEL`/`AIM_VISION_MODEL`, the benchmark script reads its two
  models and its directory, the watcher reads `AIM_SPOOL_STATE_DIR`, the
  Laserfiche folder reads `AIM_LASERFICHE_INBOX_PATH`, and the four
  `__file__`-relative resolutions now use `PROGRAM_DIR`.

  `env_file_candidates()` no longer walks parent directories or the working
  directory — a worker could previously pick up a stranger's `.env`
  depending on where it was started from. It is now `AIM_ENV_FILE` then the
  script's own directory, which is Guardrails exception 2 and nothing more.

  16 new pytest tests (25 total). All seven workers were smoke-imported
  against a temp environment: every one imports, and importing creates no
  directory.

- [ ] **0.7 Add `bin/deploy-aim-workers`, shipping code *and* config.**
  Copies `script/python/aim/` from the repo to `_PROGRAM` on the AIM share,
  mirroring the existing `bin/deploy-dev` and `bin/deploy-stage`
  conventions. Must be in place before any Python change ships to
  GSA-SCAN02.

  **It also writes `_PROGRAM/.env`, containing only the `AIM_*` subset** of
  the repo `.env`. Decided 2026-09-08. This is what closes the manual hop
  described in `## Environment Reference → How configuration reaches the
  workers`; without it a variable added to LockBox never reaches a worker.
  Extracting only `AIM_*` also keeps `ENTRA_ID_CLIENT_SECRET`,
  `POSTGRES_PASSWORD` and the rest of Paperboy's secrets off the share.

  Code and config ship in the same run, so they cannot drift apart again.
  **Verify provenance before shipping.** The repo `.env` is *supposed* to
  be a copy of `LockBox/Paperboy.env`, but nothing enforces that — a
  hand-edited repo copy would send the workers a value LockBox never
  defined, and the deploy would look entirely successful. The script must
  compare the two and refuse to ship when they differ, or stamp the
  rendered file with the LockBox commit it came from. This is the
  difference between LockBox being the definition point and LockBox merely
  being where the values happened to start.

  While here, fix `_prepare_aim_environment.bat:38`, which tells a human to
  copy the env file to a literal `E:\AIM\_PROGRAM\.env`. That is stale
  advice once this step lands, not a rule violation — the `.bat` files are
  out of scope per `## Guardrails`.
  *Test:* dry-run mode lists what it would copy and which variables the
  rendered `.env` would contain; a real run round-trips a checksum
  comparison; the rendered file contains every `AIM_*` variable and no
  non-`AIM_*` one.
  *Note:* the worker install folder is `_PROGRAM` on the AIM share
  (`/mnt/a/_PROGRAM`), confirmed 2026-09-04 — the workers and their `.env`
  are already there.

- [ ] **0.8 Make the suite enforce the protocol.** Add
  `test/lib/aim/configuration_conventions_test.rb`, which scans the AIM
  Ruby and Python for literal paths, share names, ODBC driver strings,
  model names and credentials, and fails with a clear message naming the
  file and line. Model it on the existing
  `test/lib/stylesheet_conventions_test.rb`, which already does exactly
  this for SCSS and is the reason those rules have held.
  After this step, a hardcoded path is a red build rather than something
  discovered months later.
  *Test:* the guard fails on a deliberately planted literal and passes on
  the cleaned tree.

## Phase 1 — Stop The Silent Data Loss

Small, surgical, no schema changes. Highest value per line changed.

- [ ] **1.1 `insert_sql_record` raises when no columns map.** Today it hits
  `if not columns: return` and every caller reports success. See audit C2.
  *Test:* a payload matching nothing raises; a valid payload still inserts.

- [ ] **1.2 Rename the vendor-rule sidecar.** The AI worker writes both
  `{id}.json` (vendor rules) and `{id}_READY_FOR_SQL.json` (the real
  payload) into one folder. Rename the former to `{id}_VENDOR_RULE.json`
  and teach `Aim::InvoiceQueueSupport#metadata_path_for` to ignore it. See
  audit C1.
  *Test:* Ruby — a folder containing both files resolves metadata to the
  payload. Python — the worker writes the new name.

- [ ] **1.3 SQL worker selects its payload by name.** Replace
  `json_files[0]` with an explicit search for `*_READY_FOR_SQL.json`, and
  skip the folder with a logged reason if none is found. Never treat an
  arbitrary `.json` as a payload. See audit C1.
  *Test:* a folder with a sidecar and no payload is skipped, not deleted.

- [ ] **1.4 Never delete a batch whose archive failed.** `archive_batch`
  already returns a boolean that the SQL worker ignores before calling
  `shutil.rmtree`. See audit H8.
  *Test:* archive raises, folder survives, batch moves to the failed queue.

- [ ] **1.5 Fix the handwritten-financials merge guard.** The merge loops
  skip any field whose value is not `None`, and the field defaults to
  `False`, so the vision model's answer is always discarded and the routing
  check has never fired. See audit C3.
  *Test:* a vision response with the flag true routes to Low Confidence
  Review.

- [ ] **1.6 Fix the undefined `folder_name` in the crash handler.** It leaks
  the last value from an earlier loop, so error tickets are filed under the
  wrong invoice. See audit M6.
  *Test:* a crash during processing files its ticket under the right id.

---

## Phase 2 — Make The Claim A Real Lock

- [ ] **2.1 Compare the claimant to the signed-in user.** `claim_invoice`
  returns true whenever `.claim.json` merely exists, so a second reviewer
  gets the full action strip on someone else's invoice. Add `Errno::ENOENT`
  to `WRITE_FAILURES` so the losing write is handled rather than 500ing,
  and make the queue list's "View Only" link genuinely read-only. See audit
  C4.
  *Test:* a foreign claim renders read-only; the same user resumes freely.

---

## Phase 3 — One Identity Per Invoice

- [ ] **3.1 Mint the id once.** The watcher creates `{BU}.{ts}.{name}` and
  names the folder that, but drops the PDF under its original filename; the
  AI worker then mints a different id from that filename. Rename the PDF to
  the batch id on spool, and have the worker adopt `job_ticket.json`'s
  `processing_id`. See audit H3.
  *Test:* the id in the AI queue equals the id in every downstream queue.

- [ ] **3.2 Preserve BU and submitter through Retry.** The Rails retry
  action copies only the PDF, so the worker falls back to `BU = "Unknown"`.
  Write the metadata sidecar the reprocess path already knows how to read.
  See audit H2.
  *Test:* a retried invoice keeps its Budget Unit.

---

## Phase 4 — Stop Corrupting The Key Fields

These are a prerequisite for duplicate detection, because the business key
is built from these values as strings.

- [ ] **4.1 Stop mangling vendor names.** `sanitize_data` rewrites `&` to
  `and`, which changes the business key for 58 of ~900 official vendors and
  makes the Laserfiche XML disagree with the SQL row. See audit H5.
  *Test:* `AT&T MOBILITY` survives extraction and XML generation intact.

- [ ] **4.2 Stop stripping invoice and order numbers.** `_clean_text_field`
  removes everything outside `[a-zA-Z0-9_\- ]`, so `INV-2024/001` becomes
  `INV-2024001`. Keep the characters vendors actually use.
  *Test:* punctuation-bearing invoice numbers round-trip unchanged.

- [ ] **4.3 Canonicalise money formatting.** One representation for totals
  everywhere, so `100.0`, `100.00` and `$100.00` cannot produce three
  different business keys.
  *Test:* the three inputs produce one canonical stored value.

---

## Phase 5 — Move State Off The Filesystem

The core restructure. Needs Joshua's approval on the migration before 5.1.

- [x] **5.1 Where the AIM tables live — DECIDED.** `GSA_Scan` on
  `gsa-sql22`, alongside the AIM tables already there. Not the Paperboy
  database. This needs a new `aim` connection entry in
  `config/database.yml`, pointed at `GSA_Scan` in every environment except
  test, which uses **`AIM_Test`** on the same server.
  *Shared config — bring Joshua the `database.yml` diff before making it.
  It must be purely additive: a new key, no edits to the existing anchor
  or to any current environment.*

- [ ] **5.1a Create `AIM_Test` on `gsa-sql22`.** An empty database. AIM
  migrations load into it; the `aim_*` tables are tested against it. This
  one is ours and is AIM-branded, unlike `Paperboy_Test`.
  *Test:* AIM model tests run green against it without touching
  `GSA_Scan`.

- [ ] **5.2 Migration: `aim_invoices`.** One row per invoice. `batch_id`,
  `business_key`, `budget_unit`, `submitter`, `document_type`, `state`,
  `claimed_by`, `claimed_at`, `assigned_to`, `assignment_source`, vendor
  columns, typed money and date columns, timestamps. Typed properly —
  `decimal` for money, `date` for dates.
  *Test:* migration runs up and down cleanly; model validations covered.

- [ ] **5.3 Migration: `aim_invoice_events`.** Append-only history. Who did
  what, when, from which state to which. This is the audit trail the
  pipeline has never had.
  *Test:* every state transition writes exactly one event.

- [ ] **5.4 `Aim::Invoice` model and state machine.** States enumerate the
  real queues plus the terminal outcomes. Illegal transitions raise.
  *Test:* the full transition table, including every rejection.

- [ ] **5.5 Rails reads state from the database.** Queue screens and the
  work provider read rows, not directories. Files stay on the share as
  blobs. Dual-run against the folders during this step.
  *Test:* queue counts from the database match the folder counts.

- [ ] **5.6 Workers write state to the database.** Each worker records its
  transition instead of implying it by moving a folder.
  *Test:* a full pipeline run through the fake tree produces the expected
  event sequence.

- [ ] **5.7 Retire folder-as-state.** Remove `.claim.json`, remove the
  status-by-location inference, remove the Windows shortcuts.
  *Test:* the suite passes with no code reading a folder to learn status.

---

## Phase 6 — Real Vendor Normalization

- [ ] **6.1 Migration: `aim_vendors` and `aim_vendor_aliases`.** Canonical
  vendors with an id, and many aliases pointing at one vendor. Vendors not
  present in Fiscal's list are flagged provisional.
  *Test:* model and association coverage.

- [ ] **6.2 `aim:import_vendors` rake task.** Loads Fiscal's CSV, reports
  what matched, what is new, and what did not match.
  *Test:* fixture CSV produces the expected counts and no partial writes.

- [ ] **6.3 Migrate the existing aliases.** Import the 907 SQL rows and 904
  JSON keys, reconcile the divergence, and collapse the 52 known duplicate
  groups. 897 of the JSON entries currently map to themselves.
  *Test:* a fixture of the known duplicate groups collapses correctly.

- [ ] **6.4 One source of truth.** SQL is authoritative; the JSON becomes a
  read-through cache with no write-back. Disable AI auto-learning until
  there is a delete path and an audit trail.
  *Test:* a deleted alias stays deleted across a worker restart.

- [ ] **6.5 Vendor admin screen.** Merge, rename, delete, and promote a
  provisional vendor. Replaces the 900-option dropdown with a search.
  *Test:* controller coverage for each action.

---

## Phase 7 — Duplicate Prevention

- [ ] **7.1 Persist `business_key` and index it.** A filtered unique index
  that excludes placeholder rows, so an invoice missing its number is not
  dedupe-blocked but sent to review instead.
  *Test:* two identical invoices collide; two incomplete ones do not.

- [ ] **7.2 Enforce at the final gate.** Hard block on an exact four-field
  match before the fiscal handoff. Warn, with the matching record shown,
  when vendor and invoice number match but amount or date differ.
  *Test:* both paths, including the reviewer override on a warning.

---

## Phase 8 — Close The Dead-End Queues

Each of these retires a Windows file-share shortcut.

- [ ] **8.1 Expose `_ERROR_QUEUE`.** It has 9 batches in it today and is
  invisible in Paperboy. Needs a `BACKEND_QUEUES` entry, a `PATH_ENV`
  entry, and retry/manual/archive actions.
- [ ] **8.2 Batch Split approve action.** Today the only way to approve a
  split is the `MOVE_FOLDERS_HERE_TO_SPLIT.lnk` shortcut.
- [ ] **8.3 Splitter correctness.** Fix the submitter parsed from the wrong
  path segment, validate that the manifest covers every page, prevent
  duplicate `split_id` overwrites, and close the PDF handle in a `finally`.
- [ ] **8.4 SQL Failed re-send and Rejected reopen.**
- [ ] **8.5 Manual Processing queue and manual entry form.**

*Test, each:* controller coverage for the new action plus a queue-count
assertion.

---

## Phase 9 — User Approval

- [ ] **9.1 BU access model.** Which users can see which Budget Unit queue,
  through Paperboy's existing groups and ACL. Follows the
  `AuthorizedApprover` pattern rather than reusing that table.
- [ ] **9.2 The `user_approval` queue.** It has never worked: the folder
  does not exist on the share, `user_approval` is missing from
  `BACKEND_QUEUES` so the screen redirects, and no worker reads the
  directory. See audit H1.
- [ ] **9.3 Approve, edit metadata, add notes.** With the event trail from
  5.3 recording each.
- [ ] **9.4 Assignment.** `assigned_to` plus `assignment_source`, so a
  coversheet barcode can populate it later without redesign.
- [ ] **9.5 Paperboy inbox integration.** Fix `Aim::WorkProvider` so inbox
  exposure matches the screens' own access gate, and stop putting an email
  address in `assignee_employee_id`.

*Blocked on:* the pfa refactor landing on master, since `Aim::WorkProvider`
subclasses `Pfa::Work::Provider`.

---

## Phase 10 — Observability

- [ ] **10.1 Logging in every worker.** Only the AI extraction worker logs
  today.
- [ ] **10.2 Stop forcing `Status = "SUCCESS"`.** The SQL worker overwrites
  the status immediately before inserting the tracking row, so
  `Aim_Processing_Logs` cannot record a failure.
- [ ] **10.3 Redirect the `.bat` launchers** to timestamped files under
  `_Logs`.
- [ ] **10.4 Spool state lifecycle.** Delete the marker on a clean spool;
  retain only when the source could not be removed, with a TTL. Log every
  silent skip.

---

## Phase 11 — Fiscal Handoff

Shape still to be determined with Fiscal. Currently: the invoice reaches
Docushare, Fiscal assigns check numbers and dates, and a CSV in a fixed
layout feeds another system. The target is the same flow through Laserfiche.

- [ ] **11.1 Populate the chart-of-accounts columns** from the vendor/BU
  lookup.
- [ ] **11.2 The fiscal export** in the layout Fiscal specifies.

---

## Open Questions

- **Pre-existing suite failures (found in 0.1).** 213 of 537 tests are red
  on a clean master checkout, none of it AIM's doing. Three causes, all
  outside AIM and so all needing Joshua's decision before anyone touches
  them:
  1. **98 errors: `undefined method 'stub'`.** `Gemfile.lock` pins
     minitest 6.0.6, which removed `minitest/mock`; the tests calling
     `SomeClass.stub` have nothing providing it. Fixing it means adding a
     gem — shared config, needs approval.
  2. **Parallel runs are unusable.** Fixture teardown truncates
     FK-referenced tables and SQL Server refuses. Needs `delete` instead
     of `truncate`, or FKs dropped around teardown.
  3. **`DslGroupUpdaterTest` mutates real config files** in
     `config/data_runner/dsl/`.
  Until 1 and 2 are settled, "the suite is green before and after" cannot
  mean literally green. The workable standard is: *serial run, and the
  same 324 tests pass after as before.*
- **5.1** Paperboy database or `GSA_Scan` for the new AIM tables?
- ~~**0.2** Exact worker install folder on the AIM share.~~ Answered
  2026-09-04: `_PROGRAM` (`/mnt/a/_PROGRAM`).
- ~~**`P2M_PRINTERS` is missing from LockBox.**~~ Resolved 2026-09-08 by
  someone on the P2M side: LockBox master gained `P2M_PRINTERS=99_Printers`
  (`292b3a8`) and `P2M_DESTROYED=04_Destroyed` (`da5d6da`). The local
  stopgap has been removed and the baseline is unchanged with the real
  value. Worth remembering as a live example of the boot-vs-use rule in
  `## Guardrails`: `app/services/p2m/paths.rb:13` fetches at *module load*,
  so one absent variable aborted the whole suite — Billing, Forms and AIM
  included — which is exactly what that rule exists to prevent. **Pull
  LockBox before assuming a missing variable is a bug.**
- ~~**Python tests in CI.**~~ Settled 2026-09-08: **not** wired into
  `.github/workflows/ci.yml`. The pytest command is a local gate step
  instead -- see `## How We Work -> The CI gate` for the reasoning and the
  fallback if it ever needs revisiting.
- **CI's push trigger has never fired.** `.github/workflows/ci.yml` runs on
  `push: branches: [main]`, but this repository's default branch is
  `master`, so only `pull_request` ever runs CI. Not AIM's to fix, and no
  change made -- but worth knowing before trusting "CI is green on master".
- **Laserfiche import mechanism.** Not designed yet, and blocked on IT
  resolving a Laserfiche need. The likely shape is a monitored folder on
  GSA-SCAN02 that LF auto-imports from, but that could change. Noted
  2026-09-08.
  `AIM_LASERFICHE_INBOX_PATH` is still added in 0.2, pinned to today's
  literal `\AIM\00 INBOX\`, precisely so that settling this later is a
  LockBox value change and not a code change. Do not design the Laserfiche
  handoff around the current value.
- **11** Final field layout Fiscal needs, and whether the existing
  `Aim_Invoices` approval columns stay authoritative or the new tables do.
- Whether the existing 207 rows in `Aim_Invoices` and `Aim_Processing_Logs`
  are worth migrating or can be left as history.

---

## Progress Log

Append one line per pushed step: date, step number, commit, result.

| Date | Step | Commit | Result |
|---|---|---|---|
| 2026-09-04 | 0.1 | (no code) | `Paperboy_Test` created; baseline 537 runs, 324 pass, 60 fail, 153 error, 0 skips (serial) |
| 2026-09-08 | 0.2 | 8127afbc, 55e3b231 | Inventory complete; 12 variables added on LockBox branch `aim-config` (`a68212c`, local only) |
| 2026-09-08 | 0.2 | (baseline reset) | Master moved on 15 commits; new baseline 544 runs, 333 pass, 59 fail, 152 error (serial) |
| 2026-09-08 | 0.2 | `5e0de53` (LockBox) | Pulled LockBox: P2M added `P2M_PRINTERS`/`P2M_DESTROYED`; rebased `aim-config`, dropped the stopgap, baseline unchanged |
| 2026-09-08 | 0.3 | (this commit) | Fallbacks removed from AIM Ruby; audit M3 fixed; 552 runs, 341 pass, 59 fail, 152 error |
| 2026-09-08 | 0.4 | (this commit) | `pipeline_common` import made pure; deps moved to requirements.txt; 4 pytest tests green, Ruby suite unchanged |
| 2026-09-08 | 0.5 | 170ab1e4, 01e85597 | Python harness stood up, 9 pytest tests green; CI deliberately unchanged |
| 2026-09-08 | 0.6 | 8f7419d9 | AIM Python literals removed; `env()` fallback parameter deleted; 25 pytest green, Ruby suite unchanged |
