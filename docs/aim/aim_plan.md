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

### The standing exception: AIM's own triggers

Granted by Joshua 2026-09-22, after asking what the permission was actually
for: *"so long as the changes won't hurt anything else or cause issues
anywhere else, then you can make this change since it sounds like it's just
an addition."*

AIM can already do its work; what it lacks is somewhere to put the trigger,
because Rails looks for triggers in fixed shared places. These four may be
added **without asking each time**:

```text
lib/tasks/aim_*.rake          a task a person runs
app/jobs/aim/*_job.rb         a job, for work that runs on a schedule
config/recurring.yml          one new block, naming an Aim:: job
config/routes.rb              a new route inside the existing aim namespace
app/models/app_feature.rb     new entries inside AIM's own 'aim' block
```

The last line was added by Joshua on 2026-09-23 -- *"yes, so long as it
doesn't break anything else"* -- so AIM's capabilities (Phase 9) can be
declared in the catalog every other app uses.

The conditions that make this safe, and that hold every time:

- **New files, AIM-named.** Nothing existing is edited, renamed or removed.
- **One added block, never a changed one.** In `recurring.yml` and
  `routes.rb` the addition sits alongside what is there; another team's
  entries are not touched.
- **The full suite is green before and after**, as for any other step.
- **Say what was added** in the step's handoff. The grant removes the wait,
  not the telling.

Anything else shared -- `database.yml`, an initializer, the Gemfile, an
existing route, another team's job -- is unchanged by this and still goes
through *Stop, show the diff, wait*.

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
- No assumption that Rails and the Python workers share a server. AIM's
  new tables do share Paperboy's database -- decided 2026-09-22, in their
  own `aim` schema -- but reach it only through Paperboy's own connection
  settings, never a literal of their own.

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

Everything AIM creates is AIM-branded and namespaced: tables in the `aim`
SQL schema (`aim.invoices`, never `dbo.anything`),
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
the legacy system being retired. The finished document reaches it as **one
PDF carrying its own metadata** -- see `## Decisions Already Made` -- not as a
PDF paired with a sidecar.

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

**A gate failure only counts when it is AIM's.** Confirmed by Joshua
2026-09-15. rubocop and brakeman run over the whole application, so they
report other teams' work alongside ours -- on 2026-09-15 rubocop was red
with 81 offences, 75 of them in one sheriff-safety migration and none of
them AIM's. Those belong to whoever wrote them, and the guardrails put
them out of reach anyway: fixing one means editing a file outside AIM.

So read each gate result for AIM's own files, and say plainly in the
handoff which failures are someone else's rather than carrying them as
though they were a blocked step. For rubocop, scope the run:

```bash
bundle exec rubocop app/controllers/aim app/controllers/concerns/aim \
                    app/helpers/aim app/services/aim app/views/aim \
                    test/controllers/aim test/services/aim test/lib/aim
```

`bundle exec rake test` is the exception and stays whole-suite: its whole
purpose is proving an AIM change broke nothing elsewhere, so a test that
AIM reddens is AIM's no matter which directory it lives in.

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
| Worker install folder | `/mnt/a/AIM/_PROGRAM` — **not** `/mnt/a/_PROGRAM`; corrected 2026-09-22. `bin/deploy-aim-workers` resolves it from `AIM_PROGRAM_DIR` and is unaffected |
| AIM share (Windows) | `E:\AIM` on GSA-SCAN02 |
| Worker environment file | `/mnt/a/AIM/_PROGRAM/.env` |
| Paperboy environment file | repo `.env`, from `LockBox/Paperboy.env` |
| Queue folders | `/mnt/a/AIM/_BACK_END/` |
| Watch tree | `/mnt/a/AIM/Invoices/<BU>/<Submitter>/` |

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

**A value ending in a backslash breaks the workers, and Rails will not warn
you.** Found 2026-09-21, refreshing the repo `.env` after LockBox's ROOT
consolidation. `Paperboy.env` line 14 reads:

```text
AIM_WINDOWS_ROOT='E:\'
```

Ruby's dotenv treats a single-quoted value as literal and reads it fine, so
every Rails screen is happy. `python-dotenv` treats the backslash as
escaping the closing quote, so the value runs on and it discards **both**
that variable and `AIM_BASE_DIR` on the next line. `pipeline_common.py`
reads `AIM_BASE_DIR` at import and is built to refuse to start without it,
so the whole worker fleet would fail at startup the moment
`bin/deploy-aim-workers` ships that file. It is the only line in all 135
variables with the defect, and it is AIM's own variable.

Two forms parse identically in both languages; the double-quoted one
matches LockBox's own "Surround variables with double quotes" convention:

```text
AIM_WINDOWS_ROOT="E:\\"
AIM_WINDOWS_ROOT=E:\
```

**Fixed and pushed the same day.** LockBox `019ca7c` quotes it as
`AIM_WINDOWS_ROOT="E:\\"`, which both readers parse to `E:\` identically,
and the repo `.env` was refreshed from it. All 135 variables parse in Ruby
and in Python; all 59 `AIM_*` survive the subset the workers receive. The
share copy was never written with the bad file, so the fleet never saw it.

**The deploy script now refuses to ship a file the workers cannot read**, so
this class of fault cannot reach the share again. `bin/deploy-aim-workers`
already counted the `AIM_*` lines it copied and checked that nothing else
leaked in; neither proves the file *parses*. It now reads the rendered file
with `python-dotenv`, exactly as a worker will, and dies on two conditions:

- **a discarded variable** -- the backslash fault above, and anything else
  the two readers disagree about;
- **a dangling interpolation** -- an `AIM_*` value referring to a variable
  the `AIM_*` subset leaves behind. That one is specific to stripping the
  file down for the share: `AIM_FOO=${GSABSS_ROOT}/x` looks right in the
  repo and silently resolves to `/x` on GSA-SCAN02.

Both are covered by `test/python/aim/test_deploy_workers.py`, which plants
each fault and asserts the deploy refuses and writes no `.env`. Adding the
guard turned that file's existing tests red, which was the guard working:
they run the script in a subprocess, whose `python3` has no `python-dotenv`.
They now pass the interpreter running pytest, the way a developer passes the
worker venv. The
interpreter comes from `AIM_DEPLOY_PYTHON`, defaulting to `python3` on PATH;
point it at the worker venv when the system python lacks `python-dotenv`,
which the error message says. No path to that venv is written down anywhere
in the script.

The manual check below is still worth knowing, since it is what the guard
automates and it works on any file:

```bash
grep -E '^AIM_[A-Z0-9_]+=' .env > /tmp/aim.env
~/.venvs/aim/bin/python -c "from dotenv import dotenv_values; d=dotenv_values('/tmp/aim.env'); print(len([k for k,v in d.items() if v is not None]))"
```

That count must equal `grep -cE '^AIM_' .env`.

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
| Test database | -- | `Paperboy_Test` (also holds the `aim` schema) |
| Tables | `Aim_Invoices`, `Aim_Processing_Logs`, `Aim_Vendor_Aliases` (legacy) | `aim.*` from Phase 5 |
| Read by | Python workers, and Rails once connected | Rails |

The new `aim.*` tables are tested like every other Paperboy table: in
`Paperboy_Test`, and in the per-worker databases a parallel run builds from
`db/schema.rb`, which carries `create_schema "aim"`. `AIM_Test` was planned
for the `gsa-sql22` placement and is no longer needed.

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
  **Reconfirmed by Joshua 2026-09-22, with `Statement` added:** the list is
  `Invoice`, `Memo`, `Credit`, `Coupon`, `Statement`, `Unknown`. The
  extraction worker's `INVOICE`/`STATEMENT`/`CREDIT`/`UNKNOWN` is
  incomplete, not a competing decision -- step 5.3a teaches it all six.
  **`Unknown` is temporary.** AIM staff replace it during QA review, and an
  invoice does not go to a user's queue while it is still `Unknown` -- a
  rule for the 5.4 state machine.
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
- **Metadata is embedded in the PDF, not shipped beside it as XML.** Decided by
  Joshua 2026-09-08, from a working Laserfiche setup on another project. Fields
  are written as **custom keys in the PDF Info dictionary** -- not XMP, no
  namespace, no schema to register -- and Laserfiche reads each one by name as
  `%(PDFmetadata_<Key>)`, spaces written as underscores. Verified against a
  real example: `Box_Number`, `Vendor`, `Record_Series_Code` and the rest sit
  in the Info dictionary of a file Laserfiche already indexes.

  This removes the failure the XML causes rather than managing it. The XML is a
  second copy of the truth in a second file: it can drift from the SQL row
  (audit H5 / step 4.1), be regenerated wrong (step 1.3 found every
  manually-corrected invoice reaching Laserfiche with `TemplateName` `Unknown`),
  or be orphaned from its PDF. One file carrying its own metadata has none of
  those states.

  Mechanics, confirmed 2026-09-08:

  - `pymupdf` is already in `script/python/aim/requirements.txt`, so stamping
    costs no new dependency. `set_metadata()` only reaches the standard keys;
    custom ones are written with `xref_set_key` on the Info object.
  - A round-trip preserved `AT&T MOBILITY` and `INV-2024/001` exactly -- the
    values steps 4.1 and 4.2 exist to stop mangling.
  - **The original PDF is archived before stamping.** Agreed with Joshua; a
    stamp rewrites the file, and the document as received has to survive.
  - The stamp happens at handoff, generated from the invoice row. Nothing edits
    metadata inside a PDF in place, so this is consistent with Phase 5: the row
    is the truth and the PDF is an export artifact.

  Consequence: `generate_laserfiche_xml` and the `.xml` sidecar are retired in
  Phase 11, not carried alongside the new path.
- `aimusers` / `GSABSS.dbo.aimusers` is **not** in scope and is not the
  source for BU access.
- **Database placement (settles step 5.1) -- revised by Joshua 2026-09-22.**
  The new AIM tables live **in the Paperboy database on `GSASQL16`, in a SQL
  schema named `aim`**: `aim.invoices`, `aim.invoice_events` and so on. They
  are reached through the connection Paperboy already has, as the shared
  `GSAETL` login -- "use ETL whenever we can; it is the shared username and
  password in LockBox that should have access to all resources."

  This replaces the original answer, `GSA_Scan` on `gsa-sql22`, which fell
  over on two facts found in 5.1: the plan's `aim_invoices` *is* the legacy
  `Aim_Invoices` in that case-insensitive database, and `GSAScanCenter` can
  create neither a database nor a table there. On `GSASQL16`, `GSAETL` is
  `db_owner` of `Paperboy_Dev` and `Paperboy_Test`.

  What it buys: no second Rails connection, so no change to
  `config/database.yml`, `test_helper.rb` or CI, no new rake tasks, and no
  new LockBox variables for Rails. Migrations are ordinary `db/migrate`
  files and `db/schema.rb` is their regenerated output -- both already on
  the allow-list. The `aim` schema is the AIM branding the Naming guardrail
  asks for, and keeps the new tables visibly apart from everything else.

  What it costs: the legacy `Aim_*` tables stay on `gsa-sql22`, so until
  Paperboy migrates, AIM's data spans two servers -- the workers will write
  a legacy row there and state here, and those cannot share a transaction.
  Accepted by Joshua; it ends when Paperboy moves to `gsa-sql22` and the
  schema moves with its database.
- **Two servers, today.** Paperboy's own databases -- now including the
  `aim` schema -- are on `GSASQL16`; the legacy `Aim_*` tables are on
  `gsa-sql22`, where the Python workers write them. Rails does not read the
  legacy tables, so it still needs no second connection.
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
  lives in it. **AIM's own Phase 5 tables live here too, in
  the `aim` schema** -- see *Decisions → Database placement*.

  Do not rename `Paperboy_Test` to something AIM-branded. It holds all 113
  migrations' worth of Paperboy tables, and the name comes from shared
  config that every other developer's test run depends on.

  **Done 2026-09-04. Baseline: 537 runs, 324 pass, 60 failures, 153
  errors, 0 skips** (serial). **Superseded 2026-09-08** — the phase branch
  was cut from a master 15 commits newer, where the suite is 544 runs, 333
  pass, 59 failures, 152 errors. **Superseded again the same day** after
  merging 26 further commits from master, including the Rails 8.0 to 8.1
  upgrade: **616 runs, 398 pass, 58 failures, 160 errors** (serial). Compare
  against that.

  Two of those commits fix things this plan had recorded as problems:
  `6a3bcdbf` gives each parallel run a unique database namespace and drops
  its worker databases when the run ends, and `9dde40ac` isolates the DSL
  test writes so `rake test` no longer dirties `config/data_runner/dsl/`.
  Both confirmed here. All seven red AIM tests are identical before and
  after the merge — the `stub` problem and a `Struct` keyword error, both
  pre-existing and neither caused by AIM. The suite now runs to completion, which was
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

- [x] **0.7 Add `bin/deploy-aim-workers`, shipping code *and* config.**
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

  **Done 2026-09-08, and deployed.** Dry run is the default; `--apply`
  writes. Provenance is enforced: the run refuses if the repo `.env` differs
  from `LockBox/Paperboy.env`, prints the diff, and stamps the rendered file
  with the LockBox commit. `--skip-provenance` exists for emergencies and
  warns.

  **Replaced files are kept on the server.** Every `--apply` moves what it is
  about to overwrite into `_PROGRAM/_PREVIOUS_SCRIPTS/<YYYY-MM-DD>/` first; a
  second deploy the same day gets its own timestamped folder. Joshua's
  standing instruction, 2026-09-08: do this every time an established step is
  replaced, because the workers run unattended and the last working version
  has to be one copy away on the server.

  **Runtime state the share owns is never shipped.** `vendor_aliases.json` is
  written by the workers: the share had 907 keys and the repo copy 904, so
  deploying it would have deleted three aliases learned in production (Canon
  U.S.A., Vortex Industries, Team Play Events). It is on a permanent
  exclusion list. Anything else the workers write must be added there too.

  **Two bugs the dry run caught before they could do harm:** the
  Windows-to-Linux translation silently failed and resolved the target to
  `E:/AIM/_PROGRAM` (a backslash inside a bash pattern is an escape), and the
  script originally sourced `.env`, which executes whatever it contains and
  broke on a `DATARUNNER_*` value that is not valid shell. It now parses the
  three variables it needs and refuses if the prefix does not match.

  **Deployed result:** 22 files plus a rendered `.env` of 58 `AIM_*`
  variables and nothing else. The share `.env` went from 111 variables to 58,
  taking `ENTRA_ID_CLIENT_SECRET`, `POSTGRES_PASSWORD` and eight other
  non-AIM secrets off the share. `AIM_AI_QUEUE_DIR` is on the share for the
  first time, so Rails and the workers finally read the same variable.

  **On restart, expect no pip self-install.** `install_prerequisites()` is
  gone (step 0.4), so a missing dependency now fails immediately instead of
  installing itself. Nothing new was added; if one does fail,
  `pip install -r requirements.txt` in `_PROGRAM` fixes it.

  `bin/` is not in the Guardrails' allowed paths. This is a new AIM-only
  file the plan calls for, not an edit to anything shared.

- [x] **0.8 Make the suite enforce the protocol.** Add
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

  **Done 2026-09-08.** `test/lib/aim/configuration_conventions_test.rb`
  with `configuration_scanner.rb` beside it. Eight rules: no Windows path,
  UNC share or mount point; no queue folder literal; no ODBC driver or
  encryption setting; no model name; no server name or credential; `env()`
  takes a name and nothing else; `env()` is never called with a fallback;
  the `.env` seed does not walk parents or the working directory. A ninth
  checks that AIM's own tests never reference the real share or a real
  server, since a test that touches `/mnt/a` breaks for anyone who has not
  pulled LockBox.

  **Verified by planting eight violations** — a Windows path, a mount
  point, a server name, a credential, a queue folder, a model name, an ODBC
  connection string and an `env()` fallback — and confirming six of the
  eight tests went red and named the file and line. The tree was then
  restored and the suite re-run green. A guard nobody has watched fail is
  not a guard.

  **Precision was the hard part, and it is the point.** The first version
  flagged `.claim.json`, `ollama` (for containing "llama"),
  `Encrypt={encrypt}` and the phrase "Routed to _BATCH_SPLIT for human
  review" in a log message. A guard that cries wolf gets switched off, and
  the protocol it defends then rots. So it distinguishes a folder used as a
  *path component* from one merely named in a message, skips Python
  docstrings, and ignores `.bat` launchers per Guardrails exception 1.

## Phase 1 — Stop The Silent Data Loss

**Branch `aim/phase-1-dataloss`, cut from master 2026-09-08 after Phase 0
merged (`8e4a6dda`).**

Before starting a step here, read `## Guardrails` and note what Phase 0
changed about how you work:

- Run the suite **serially**: `PARALLEL_WORKERS=1 bundle exec rake test`.
- The gate has a fifth command: `~/.venvs/aim/bin/pytest test/python/aim`.
- The baseline to compare against is **624 runs, 406 pass, 58 failures, 160
  errors**. The red is pre-existing and none of it is AIM's; the standard is
  that the same tests pass after as before, not that the suite is green.
- `env()` takes a name and nothing else, and
  `test/lib/aim/configuration_conventions_test.rb` fails the build on a
  hardcoded path, model name or credential. Add the variable to LockBox
  rather than working around the guard.
- A Python change reaches GSA-SCAN02 only through
  `bin/deploy-aim-workers --apply`, which needs `LOCKBOX_DIR` set.

Small, surgical, no schema changes. Highest value per line changed.

- [x] **1.1 `insert_sql_record` raises when no columns map.** Today it hits
  `if not columns: return` and every caller reports success. See audit C2.
  *Test:* a payload matching nothing raises; a valid payload still inserts.

  Done 2026-09-08. Raises the new `SqlMappingError`, naming the table, the
  mapping's keys and the payload's, so the failed-queue folder says why. The
  SQL worker's existing `except Exception` around the billing insert already
  routes the batch to the failed queue, so no caller changed.

  Two things found on the way:

  - `insert_sql_record` **could not run at all**. Step 0.6 removed `env()`'s
    fallback parameter but left the call `env(f"{prefix}MAPPING_FILE", '')`
    here, so every invocation raised `TypeError`. Nothing caught it because
    nothing tests it. Fixed with the call, and the now-unreachable "no
    MappingFile configured" skip deleted -- `env()` exits naming the variable.
    A grep of `script/python/aim/*.py` found no other two-argument call, so
    this was the last one 0.6 missed.
  - The **mapping file missing from disk** was a silent `return` a few lines
    above, failing in exactly the same way: success printed, batch deleted,
    no row. Outside 1.1's wording, so it became step 1.1a below.

- [x] **1.1a A missing mapping file raises too.** The sibling of 1.1, in the
  same function: `insert_sql_record` printed "Mapping file ... not found" and
  returned, so a mapping that was mistyped or never deployed lost invoices the
  same way. Added by Joshua's decision 2026-09-08, on the finding recorded in
  1.1. Now raises `SqlMappingError` naming the resolved path and the variable.
  *Test:* an absent mapping file raises and executes no SQL; an absolute
  configured path is used as-is.

  Safe to raise because nothing legitimately runs without the file: both
  `Aim_Invoices_MAPPING.json` and `Aim_Processing_Logs_MAPPING.json` are in
  `script/python/aim/` and on the share, and `bin/deploy-aim-workers` ships
  `*.json`, so the two cannot drift. An absent file now means something is
  actually broken, and the batch stops instead of vanishing.

  Kept out of 1.3 deliberately: 1.3 is `02_sql_worker.py` choosing which JSON
  is the payload, a different file and a different question.

- [x] **1.2 Rename the vendor-rule sidecar.** The AI worker writes both
  `{id}.json` (vendor rules) and `{id}_READY_FOR_SQL.json` (the real
  payload) into one folder. Rename the former to `{id}_VENDOR_RULE.json`
  and teach `Aim::InvoiceQueueSupport#metadata_path_for` to ignore it. See
  audit C1.
  *Test:* Ruby — a folder containing both files resolves metadata to the
  payload. Python — the worker writes the new name.

  Done 2026-09-08. The sidecar was written in three identical inline blocks;
  they are now one `write_vendor_rule_sidecar()` and the name comes from a
  single `VENDOR_RULE_SUFFIX` constant, mirrored in Ruby as
  `Aim::InvoiceQueueSupport::VENDOR_RULE_SUFFIX` with a test asserting the two
  strings match. `metadata_path_for` now prefers a `*_READY_FOR_SQL.json`
  explicitly rather than trusting `Dir.children` order, and the filtering moved
  into `metadata_candidate?`.

  Not renamed: the **vendor-review payload** at `01_AI_Extraction_Worker.py`
  line 466 is also `{id}.json`, but it is real invoice metadata and the review
  screen reads it. Only the three rule sidecars moved.

  Two findings for later steps:

  - **1.3 needs more than the step says.** `write_log` puts the SUCCESS
    payload in the SQL queue as `{id}.json` (`pipeline_common.py:325`) and
    only the ACTION_NEEDED copy as `{id}_READY_FOR_SQL.json`. Searching the
    SQL queue for `*_READY_FOR_SQL.json`, as 1.3 is written, would skip every
    normally-processed invoice. The SUCCESS write has to be renamed in the
    same step, or 1.3 has to accept both names.
  - **`test/controllers/aim/invoices_controller_test.rb` proved nothing.**
    Every test in it redirected to `/` with "You do not have access". The
    first reading -- that `can_access_app?('aim')` was crossing to GSABSS --
    was wrong. `current_user` returns nil unless the session hash carries
    **both** `email` and `employee_id`, and the file only set `email`, so
    `require_app_access` failed on `current_user.present?` before the ACL
    was ever consulted. Fixed in 1.2a below.

- [x] **1.2a Make the AIM controller tests run at all.** Every test in
  `test/controllers/aim/invoices_controller_test.rb` redirected to `/` before
  reaching any AIM code, so the queue screens had no coverage and a broken one
  would not have failed the build. Cause: `ApplicationController#current_user`
  returns nil unless `session[:user]` has both `email` and `employee_id`, and
  the file set only `email`. One line in `setup` fixes it; the 1.2 controller
  test then passes end to end and is kept alongside the concern test.

  Test-only, inside AIM's own file -- no shared plumbing, no fixture, no ACL
  double. The suite went from 58 failures to 57 with nothing else touched.

  Still red in that file: four tests erroring on `undefined method 'stub'`,
  which is the shared minitest/mocha pin in Open Questions and is not AIM's to
  fix. Note for future sessions: a redirect to `/` in an AIM controller test
  means the session, not the ACL.

- [x] **1.3 SQL worker selects its payload by name.** Replace
  `json_files[0]` with an explicit search for `*_READY_FOR_SQL.json`, and
  skip the folder with a logged reason if none is found. Never treat an
  arbitrary `.json` as a payload. See audit C1.
  *Test:* a folder with a sidecar and no payload is skipped, not deleted.

  Done 2026-09-08. `find_payload()` in `02_sql_worker.py` is the only way a
  payload is chosen, used by both the SQL worker and the delete worker (which
  read "any JSON" for the BU and submitter of its archive path).

  As predicted in 1.2, the step needed the naming fixed first: `write_log`
  wrote the SUCCESS payload as `{id}.json` and only the ACTION_NEEDED copy as
  `{id}_READY_FOR_SQL.json`. Both now use `PAYLOAD_SUFFIX`, defined once in
  `pipeline_common.py` and mirrored by `Aim::InvoiceQueueSupport::PAYLOAD_SUFFIX`,
  with a test asserting the two agree. No transitional acceptance of the old
  name was needed: `_SQL_QUEUE` was empty at deploy time and was checked.

  **Behaviour change worth knowing about.** The Laserfiche XML is now
  regenerated from the payload for *every* batch, not only "manual fix" ones.
  That branch identified a manual fix by its filename, which the rename makes
  meaningless -- and the test was never sound anyway, since Rails writes a
  hand-corrected vendor-review payload with `Status` `SUCCESS`
  (`Aim::VendorReviewPayloadService`). Regenerating always means the XML and
  the inserted row cannot disagree, which is the invariant step 4.1 is about.
  The regeneration also now passes `document_type` through; without it every
  regenerated XML fell back to `TemplateName` `Unknown`, so until today each
  manually-corrected invoice reached Laserfiche with its document type lost.
  This whole branch is temporary: step 11.4 deletes it along with the XML.

- [x] **1.4 Never delete a batch whose archive failed.** `archive_batch`
  already returns a boolean that the SQL worker ignores before calling
  `shutil.rmtree`. See audit H8.
  *Test:* archive raises, folder survives, batch moves to the failed queue.

  Done 2026-09-08. `archive_or_raise()` wraps the boolean in an `ArchiveFailed`
  the existing `except Exception` already routes to the failed queue, so the
  success path needed no other change.

  The **duplicate-key path had the same hole** and could not use the same fix:
  its `archive_batch` call sits inside an `except pyodbc.IntegrityError` block,
  and a raise from there escapes the per-folder loop and takes the worker down
  rather than being caught by the sibling handler. That one checks the boolean
  and calls `move_folder_to_failed` before `continue`.

  **Harness fix that came with it.** Worker modules read their queue
  directories from `pipeline_common` at import and are then cached in
  `sys.modules`, while `conftest` only dropped `pipeline_common`. The second
  test in a file therefore kept the *first* test's temp tree and silently found
  nothing -- it passed alone and failed in the file. New `import_worker`
  fixture re-imports the worker per test; the 1.2 and 1.3 test files use it
  too. Any future worker test must take `import_worker` rather than importing
  the module itself.

- [x] **1.5 Fix the handwritten-financials merge guard.** The merge loops
  skip any field whose value is not `None`, and the field defaults to
  `False`, so the vision model's answer is always discarded and the routing
  check has never fired. See audit C3.
  *Test:* a vision response with the flag true routes to Low Confidence
  Review.

  Done 2026-09-08. The three copied merge loops are now one
  `merge_vision_fields()` holding two rules, because the field types need
  different ones and using the data rule for both is the bug:

  - a **data field** is filled only while still blank, so the first pass to
    read it wins and a later guess cannot overwrite it;
  - a **risk flag** in `STICKY_TRUE_FIELDS` latches -- any pass that raises it
    raises it for the invoice.

  The latching matters beyond the reported bug. Changing the field's default
  from `False` to `None` would have made the first merge work and still lost a
  flag raised on the last page after page 1 came back clean, because the field
  would no longer be blank. That is the same shape of mistake as the original.

  Not covered by a test: the end-to-end route into `LOW_CONFIDENCE_REVIEW_DIR`.
  It sits inside `process_cpu_hybrid`, which needs Ollama and Tesseract, and
  the harness rules exclude both. The tests cover the merge, and assert the
  exact expression the routing branch uses to read it.

- [x] **1.6 Fix the undefined `folder_name` in the crash handler.** It leaks
  the last value from an earlier loop, so error tickets are filed under the
  wrong invoice. See audit M6.
  *Test:* a crash during processing files its ticket under the right id.

  Done 2026-09-08. The job dict carries `folder_name`, and the processing loop
  unpacks it like every other field, so nothing there depends on a variable
  left behind by the queue-building loop.

  **`job_folders` is now sorted**, which the step did not ask for but the test
  needed. `os.listdir` order is the filesystem's, so which invoice the leak
  landed on changed from run to run -- the first version of the test passed
  against the unfixed worker because the wrong answer happened to be the right
  one. Sorted, the queue is built in a reproducible order, the crashing
  invoice can be chosen so it is deliberately *not* the last folder seen, and
  the test fails against the old code with `['INV-2'] == ['INV-1']`.

  Worth remembering for the rest of Phase 1 and beyond: a test that passes
  against the unfixed code proves nothing, and two of the six steps here had
  one at first. Check every new test both ways.

---

## Phase 2 — Make The Claim A Real Lock

**Branch `aim/phase-2-claim`, cut from master 2026-09-14 after Phase 1
merged (`501d5059`).** Baseline: 635 runs, 56 failures, 190 errors
(serial), plus 61 pytest.

Two things about running the suite here, both found on 2026-09-14 and both
since overtaken by events -- recorded because the first one will recur:

- **`Paperboy_Test` refused a connection for a while** -- `bundle exec rake
  test` aborted with *the server principal "GSAETL" is not able to access
  the database "Paperboy_Test"*. Working around it with
  `PAPERBOY_TEST_DATABASE=Paperboy_Test0` succeeded, because the harness
  creates the base database when it is missing and drops it again after the
  run. By 2026-09-15 `Paperboy_Test` answered normally and no override was
  needed. If the suite cannot connect, try the default again before
  assuming anything is broken.

  **It recurred on 2026-09-21, and was fixed properly.** `Paperboy_Test`
  had been dropped and recreated on 2026-09-19 by another account, so
  `GSAETL` had no user in the new copy. Two things had to happen, in this
  order, and the second is the one that is easy to miss:

  1. **Access.** Joshua granted it:

     ```sql
     USE master;
     GRANT CONTROL ON DATABASE::Paperboy_Test TO GSAETL;
     ```

     `CONTROL` rather than `db_owner` membership, because adding a member
     to a fixed database role requires being in `db_owner` already, and he
     was not. `CONTROL` is grantable, covers the schema load, and is the
     only permission that allows the `DROP DATABASE` the purge does.

  2. **Contents.** Access alone left the suite red: the database was
     stamped `environment = development` and held real rows (288 in
     `dam_assets`), so `db:test:prepare` refused to purge it and 111 DAM
     tests errored on foreign-key conflicts. It was dropped and recreated
     clean, which also made `GSAETL` its owner, so the grant is now
     belt-and-braces rather than load-bearing.

  Since then the default works with no override:
  `PARALLEL_WORKERS=1 bundle exec rake test` is 921 runs, 0 fail, 0 error.
  The `Paperboy_Test0` scratch base was dropped on 2026-09-21.

  **If it happens a third time, read the stamp before assuming it is
  permissions.** `SELECT value FROM ar_internal_metadata WHERE [key] =
  'environment'` has to say `test`. A database stamped `development` is
  refused by `db:check_protected_environments` no matter what rights the
  login has, and a test database holding real rows is somebody's working
  data -- ask before wiping it rather than letting the harness do it.

  `Paperboy_TestSuite` was created 2026-09-20 and `GSAETL` still has no
  access to it. Nothing here uses it.

- **`origin/master` was 68 commits ahead of `501d5059`**, and a long run of
  them were `WIP: Fix ...` test repairs. **They fixed the pre-existing red.**
  `Gemfile.lock` is back on minitest 5.27 and `test/test_helper.rb` carries
  a `stub` compatibility shim, which is what the 190 errors were. Merged
  into `master` on 2026-09-15 as `88d5fc8b`, cleanly, with no AIM file
  touched by the merge.

**The suite is now genuinely green, so the standard changes.** The Open
Questions note saying "green cannot mean literally green" no longer holds
for causes 1 and 2. The baseline for Phase 3 is **675 runs, 0 failures, 0
errors (serial), plus 61 pytest** -- 673 after the next twelve commits from
master landed, so treat **zero red**, not the run count, as the standard. A
step that reddens anything at all is a step that is not finished.

One caveat: **`bundle exec rubocop` is red on master**, 81 offenses, none
of them AIM's -- 75 in
`db/migrate/20260912015519_create_sheriff_safety_reporting_forms_*.rb` and
the rest in the sheriff-safety and fleet-garaging controllers,
`config/routes.rb` and a PDF generator. All arrived with the upstream
commits and all sit outside AIM, so the guardrails put them out of reach.
Check AIM's own files with a scoped run:

```bash
bundle exec rubocop app/controllers/aim app/controllers/concerns/aim \
                    app/helpers/aim app/services/aim test/controllers/aim
```

- [x] **2.1 Compare the claimant to the signed-in user.** `claim_invoice`
  returns true whenever `.claim.json` merely exists, so a second reviewer
  gets the full action strip on someone else's invoice. Add `Errno::ENOENT`
  to `WRITE_FAILURES` so the losing write is handled rather than 500ing,
  and make the queue list's "View Only" link genuinely read-only. See audit
  C4.
  *Test:* a foreign claim renders read-only; the same user resumes freely.

  Done 2026-09-14. `claim_invoice` now reads the claim's owner and returns
  true only when the invoice was unclaimed and we just claimed it, or the
  claim already on it is ours.

  **Hiding the action strip was not enough.** The strip is a view, and the
  three actions behind it -- `update`, `retry`, `move_to_action_needed` --
  took no notice of who held the claim, so a posted form still saved, moved
  or reprocessed another reviewer's invoice. A `require_own_claim`
  `before_action` on those three is what makes "View Only" true; the view
  change only stops offering what the controller now refuses. `#show` and
  `#pdf` stay open, because reading someone else's invoice is fine.

  Two things worth carrying forward:

  - **Identity is compared without case, in one place.** The queue list
    compared `claimed_by != current_user_email` while `Pfa::Work::Provider`
    used `casecmp?`; the two could disagree about the same person and hand
    them a queue row saying "Review Invoice" that opened read-only. Both
    now go through `own_claim?`.
  - **The read-only banner used to state a cause it could not know**, telling
    every reader the share was unwritable. It now names the claimant when
    that is the reason, and keeps the share wording for the rest.

  `Errno::ENOENT` joins `WRITE_FAILURES`, which covers the loser of a race
  writing into a folder the winner has already moved. Note this also widens
  the controller's `rescue_from`: a vanished invoice folder now redirects to
  the queue instead of 500ing anywhere in AIM.

  Not fixed, and not 2.1's: `test/services/aim/work_provider_test.rb:12` and
  `:28` are red on master with `ArgumentError: unknown keywords:
  action_needed` from the test's own `Struct` on Ruby 4. AIM-owned red that
  wants a step of its own.

---

## Phase 3 — One Identity Per Invoice

- [x] **3.1 Mint the id once.** The watcher creates `{BU}.{ts}.{name}` and
  names the folder that, but drops the PDF under its original filename; the
  AI worker then mints a different id from that filename. Rename the PDF to
  the batch id on spool, and have the worker adopt `job_ticket.json`'s
  `processing_id`. See audit H3.
  *Test:* the id in the AI queue equals the id in every downstream queue.

  Done 2026-09-15. The watcher writes the PDF as `{processing_id}.pdf` (images
  too, after conversion) and `process_cpu_hybrid` takes the id as an argument,
  minting only when it is not given one. Three things that came out of it:

  - **The submitter's filename had nowhere left to live.** Renaming the PDF
    loses it, and `write_log` records it as the `FileName` column -- the only
    handle a reviewer has on the document they sent. The job ticket now carries
    `original_filename` and the worker passes it through, so `FileName` still
    means what it meant. A ticket written before this step has no such key; the
    worker falls back to the PDF's own name, so a batch already sitting in the
    queue at deploy time still processes.
  - **The crash id was a third identity.** The handler built
    `ERROR_{BU}.{now}.{name}`, so a crash landed under a name that matched
    neither the batch nor anything downstream. It is now `ERROR_{batch_id}`,
    which `generate_unique_id` already knew how to strip the prefix off.
  - **Rails needed nothing.** Every AIM screen finds the PDF as "the first
    `.pdf` in the folder", never by name, so the rename is invisible to it. The
    only Ruby change is an `original_filename` label in
    `Aim::InvoicesHelper::FIELD_LABELS` so the new ticket key renders readably
    on the AI queue screen.

- [x] **3.2 Preserve BU and submitter through Retry.** The Rails retry
  action copies only the PDF, so the worker falls back to `BU = "Unknown"`.
  Write the metadata sidecar the reprocess path already knows how to read.
  See audit H2.
  *Test:* a retried invoice keeps its Budget Unit.

  Found in 3.1, and this step's to fix: **the batch splitter loses the identity
  the same way.** `03_batch_splitter.py` writes `{batch_id}_SPLIT_{invoice}`
  folders into the reprocess queue with a sidecar carrying `bu` and
  `submitter`, but no job ticket -- so the worker mints a fresh id, and mints
  it *before* reading the sidecar, so the new id carries `BU = "Unknown"` even
  though the BU was sitting in a file beside it. Reading the sidecar before the
  id is settled is most of the fix; whether a split invoice should keep its
  parent's id or get a child id is the open question. 3.1 deliberately left the
  ticketless path minting, and `test_a_batch_with_no_ticket_still_mints_one`
  pins that, so changing it here is a deliberate edit to a guarded behaviour.

  Done 2026-09-15, and it was two halves rather than one:

  - **Rails had to write the sidecar at all.** `#retry` copied out the PDF and
    nothing else. It now writes `{folder}.json` beside the copy, which is the
    only name the worker's reprocess path looks for.
  - **The worker had to read it before minting.** Moving the sidecar read above
    `generate_unique_id` is what makes the BU real, because the minted id
    embeds it -- the BU had been reaching `write_log` correctly all along while
    the id said `Unknown`. That half fixes the batch splitter for free: it
    already wrote the same sidecar, and lost the BU purely to the ordering.

  Three things worth carrying forward:

  - **The Budget Unit has four spellings**, because each queue records it the
    way its own metadata does -- `BU` in the SQL payload, `bu_number` in a job
    ticket, `Budget Unit Number` in the Laserfiche XML, and `BudgetUnit`. The
    worker reads exactly one. `Aim::ReprocessSidecar` is where that table
    lives; add a spelling there rather than at a call site. `reject_invoice`
    has its own copy of the same idea (`metadata_param_value`) and was left
    alone -- it reads posted params, not a metadata file.
  - **An absent BU is written as absent, never as an empty string.** The worker
    falls back to `Unknown` on a missing key, and an empty string would beat
    that fallback and produce an id stamped with nothing at all.
  - **Vendor Review's "Learn & Retry AI" sidecar is now the same code.** It had
    its own two-line version that knew only `BU` and `Submitter`, so an invoice
    reaching it with XML metadata lost the BU exactly as Retry did. Both call
    `write_reprocess_sidecar` now. The alias learner moves that folder whole
    into the reprocess queue without renaming, so the sidecar arrives under the
    name the worker expects and that path needed no change.

---

## Phase 4 — Stop Corrupting The Key Fields

These are a prerequisite for duplicate detection, because the business key
is built from these values as strings.

- [x] **4.1 Stop mangling vendor names.** `sanitize_data` rewrites `&` to
  `and`, which changes the business key for 58 of ~900 official vendors and
  makes what Laserfiche receives disagree with the SQL row. See audit H5.
  *Test:* `AT&T MOBILITY` survives extraction and reaches Laserfiche intact --
  the XML today, the stamped PDF after 11.3. A `pymupdf` round-trip through
  the Info dictionary was checked and preserves `&` and `/` exactly, so the
  mangling is `sanitize_data`'s alone and does not come back with the new
  path.

  Done 2026-09-21. One line: the vendor name is stripped and no longer
  rewritten. `test/python/aim/test_key_fields.py` covers it, and Phase 4's
  remaining two steps belong in that same file. Three things worth carrying:

  - **58 of the 904 alias values carry an ampersand**, counted from
    `vendor_aliases.json` — the audit's number is real, and every one of them
    is an *official* name, the value the alias table answers with. The
    mangling therefore hit the canonical name rather than the extracted one:
    `sanitize_data` never touched `extracted_vendor_name`.
  - **The divergence was worst on a corrected invoice.** Rails writes the real
    name into a vendor-review payload, the SQL row keeps it, and
    `02_sql_worker` then rebuilt the XML from that payload *through*
    `sanitize_data` — so the row said `AT&T MOBILITY` and the XML said
    `ATandT MOBILITY`. Nothing else spelled an ampersand out; a repo-wide grep
    found that one line.
  - **ElementTree escapes the ampersand itself**, writing `&amp;` and parsing
    it back to `&`, so the XML never needed the substitution. That is asserted
    on the written file, not just on the parse.

  Discovered while testing, and not this step's to fix: `get_vendor_aliases`
  documents a fallback to the local JSON cache when SQL is offline, but its
  `except Exception` cannot catch a *missing* `AIM_SQL_BILLING_*` variable,
  because `env()` calls `sys.exit` and `SystemExit` is not an `Exception`. On
  a configured server that is unreachable the fallback works; with the
  variable absent the worker exits. That is the guardrails' intended
  fail-at-startup behaviour, so it is arguably right — but the docstring
  promises a fallback it does not always give. The test monkeypatches
  `get_sql_connection` rather than depending on either reading.

- [x] **4.2 Stop stripping invoice and order numbers.** `_clean_text_field`
  removes everything outside `[a-zA-Z0-9_\- ]`, so `INV-2024/001` becomes
  `INV-2024001`. Keep the characters vendors actually use.
  *Test:* punctuation-bearing invoice numbers round-trip unchanged.

  Done 2026-09-21. `_clean_text_field` no longer filters by character class.
  It now removes only what cannot survive a round trip — control codes and
  the invisible formatting codes — and collapses runs of whitespace. Every
  printable character the vendor put on the page is kept. Four things worth
  carrying:

  - **A deny-list, not a wider allow-list.** "The characters vendors actually
    use" has no end: `/`, `.`, `#`, `,`, `:`, `(`, `\` and a space all appear
    in real invoice numbers, and an allow-list is only ever one vendor away
    from being wrong again. These values are held as text, passed to SQL as
    parameters, escaped by the XML writer and written into the PDF Info
    dictionary, so nothing downstream needs a restricted character set.
  - **The old regex was not a hallucination guard**, which is the reason it
    looks defensible. `reject_hallucinated_long_strings` is the guard, and it
    still caps these fields at 50 characters. The regex kept the letters and
    deleted the punctuation, so `INV #2024-1` came out `INV 2024-1` — junk in,
    different junk out.
  - **Invisible characters are the duplicate-detection half of this.** A
    zero-width space or a non-breaking space makes two numbers that read
    identically on the page compare unequal, which Phase 7 would see as two
    invoices. They are removed and normalised respectively, and the test
    asserts the two forms come out equal rather than asserting a spelling.
  - **Path safety belongs where the path is built.** The one place a number
    names a folder is `03_batch_splitter.py`, which cleans the *manifest's*
    `invoice_number` at that line; the manifest never passes through
    `_clean_text_field`, so keeping `/` in the stored value cannot reach it.
    Nothing else in the workers or in AIM's Ruby builds a path from these
    fields. Do not re-narrow the value to protect a path.

  Left for later, deliberately: **a dash is not normalised.** A vision model
  can read `INV—1` where the page prints `INV-1`, and an em dash and a hyphen
  are different business keys. Folding them is a judgement about what the
  vendor meant rather than a round-trip fix, so it belongs with Phase 7's
  duplicate matching, not here. `customer_number` is also still never cleaned
  at all — it is in the pydantic length validator but not in `sanitize_data`,
  which is correct while it stays out of the business key.

- [x] **4.3 Canonicalise money formatting.** One representation for totals
  everywhere, so `100.0`, `100.00` and `$100.00` cannot produce three
  different business keys.
  *Test:* the three inputs produce one canonical stored value.

  Done 2026-09-21, and the step's own test passed before a line was changed:
  `_clean_money` already stripped the currency and padded the decimals, so
  those three spellings did reach `sanitize_data`'s output as `100.00`. The
  gap was on either side of it, and it took two halves:

  - **The canonical form never reached the row on the corrected path.**
    `02_sql_worker` sanitised a *copy* of the payload to regenerate the XML
    and then inserted the payload untouched, so a reviewer typing `$1,234.5`
    into Rails stored `$1,234.5` and exported `1234.50` — one invoice, two
    totals, two business keys. The worker now writes the sanitised values
    back into the payload before inserting. It writes back all five fields
    `sanitize_data` touches rather than the total alone, because the date
    splits the same way: `09/21/2026` in the row, `2026-09-21` in the XML.
  - **A credit was stored as a charge.** `(100.00)` is how an invoice prints
    one, and the brackets were dropped with the dollar sign, so the sign
    inverted silently. `100.00-`, the same amount with a trailing minus, was
    refused by `float` and became empty. Both now keep the sign. This is the
    most consequential thing in Phase 4: it changed what a number *meant*,
    not how it was spelled.

  Two smaller ones, both about having a single spelling:

  - `-0.00` and `0.00` were one amount under two keys. Zero is now `0.00`.
  - **A comma decimal is refused rather than guessed at.** `1.234,56` was
    quietly stored as `1.23`, because the comma was stripped as a grouping
    separator and the dot believed. Telling a trailing `,56` from a grouping
    comma needs a locale nobody has stated, so it returns nothing and the
    invoice goes to review. `$1,234` is unaffected — a comma followed by
    three digits is grouping.

  **A behaviour change worth knowing about:** because the sanitised values
  are written back, a payload value that is not money is now stored as NULL
  where the raw text used to survive — a total of `n/a` is no longer kept as
  `n/a`. That is the right direction for a column the business key is built
  from, but it is a change on the corrected path rather than a pure fix.

  Not touched, and not Phase 4's: **`Subtotal` and `SalesTax` are silently
  dropped.** `02_sql_worker` passes them to `InvoiceData`, which has no such
  fields, so pydantic discards them; they are never canonicalised and never
  reach the XML. They survive in the payload dict and so do reach SQL. They
  are not part of the business key, which is why this step leaves them alone
  — see Open Questions. Rails deliberately does not canonicalise either:
  one rule, in one language, at the gate every payload crosses.

---

## Phase 5 — Move State Off The Filesystem

The core restructure. Needs Joshua's approval on the migration before 5.1.

- [x] **5.1 Where the AIM tables live — DECIDED 2026-09-22.** The Paperboy
  database on `GSASQL16`, in a SQL schema named `aim`, as `GSAETL`. See
  *Decisions → Database placement* for why this replaced `GSA_Scan` on
  `gsa-sql22`. No shared config changes.

  **Proved 2026-09-22 in throwaway databases on `GSASQL16`** (created and
  dropped by `GSAETL`): a migration creates schema `aim` and
  `aim.invoices`; the schema dump writes `create_schema "aim"` ahead of the
  table, so any database rebuilt from `db/schema.rb` -- the per-worker test
  databases, CI's container -- gets the schema too; reloading that dump into
  a fresh database gives a working model with a typed `decimal` and an
  enforced unique index; and `aim.invoices` sits beside a `dbo.Aim_Invoices`
  without clashing.

  **Rules for every AIM migration, from that proof:**

  - **Name every index explicitly.** `add_index "aim.invoices", :batch_id`
    fails with *Incorrect syntax near '.'* -- the default name comes out as
    `index_aim.invoices_on_batch_id`. Pass `name:
    "index_aim_invoices_on_batch_id"`, dots replaced by underscores.
  - **Tables are written schema-qualified**, `"aim.invoices"`, in migrations
    and in `table_name`. Nothing AIM creates goes in `dbo`.
  - **The schema is created by its own first migration**, whose `down`
    drops it, so up-and-down stays clean.
  - **No database foreign keys on `aim` tables.** Found in 5.3: the
    adapter's `foreign_keys` builds its definition from the bare table names
    (`identifier.object`, `PKTABLE_NAME`), so the dump reads
    `add_foreign_key "invoice_events", "invoices"`. That `schema.rb` fails
    to load -- *Cannot find the object "invoice_events"* -- which breaks
    every test database build, for every team and CI. The model holds the
    link instead (`belongs_to`, `restrict_with_exception`). Fixing the
    adapter would be a shared initializer; not worth it for one link.
  - **Scratch databases use `RAILS_ENV=test`** with `PAPERBOY_TEST_DATABASE`
    set to the scratch name. See 5.2 for what `development` does instead.
  - **Check master's migration versions before numbering one.** Found
    2026-09-22: AIM's `20260922100000_create_aim_schema` collided exactly
    with DAM's `20260922100000_clear_dates_from_non_date_metadata`, pushed
    to master the same morning. Two migrations with one version make Rails
    refuse to migrate at all, so the merge would have stopped every
    environment; and because DAM's had already run on `Paperboy_Dev`, Rails
    there believed AIM's schema migration had run when the `aim` schema did
    not exist. AIM's three were renumbered `20260922094301`-`...03` with
    `git mv`. Round timestamps (`100000`, `110000`) are what collide --
    other teams pick them too. Use the clock, to the second.
  - **And number it after every migration that already exists**, master's
    included. The first renumber picked `...0943xx`, the real clock, which
    was *earlier* than DAM's future-dated `...100000`. Loading `schema.rb`
    then marks every migration version below the file's own version as
    already run, so AIM's three were recorded as applied and never
    executed: the `aim` tables would have been missing from every database
    built from the schema, with nothing reported. Caught by migrating a
    scratch database after the merge, which ran nothing at all. They are now
    `20260922100537`-`...39`, above master's latest.

  `test/lib/aim/schema_conventions_test.rb` enforces the first two rules
  against `db/schema.rb`: a foreign key naming a table the file never
  creates, or an index name with a dot, fails the build.

  **Worth knowing if a second database is ever needed:** Rails 8.1's
  transactional fixtures pin every registered connection pool for every
  test, and pinning calls `verify!`, which connects. With CI's `eager_load`
  an extra `connects_to` would make every test in the suite reach that
  server. `hsa_adoption_cards/connection.rb` records the same trap. The
  `aim` schema avoids it entirely.

- [x] ~~**5.1a Create `AIM_Test` on `gsa-sql22`.**~~ Not needed. The `aim`
  schema is tested in `Paperboy_Test` with everything else.

- [x] **5.2 Migration: schema `aim` and `aim.invoices`.** One row per
  invoice. `batch_id`,
  `business_key`, `budget_unit`, `submitter`, `document_type`, `state`,
  `claimed_by`, `claimed_at`, `assigned_to`, `assignment_source`, vendor
  columns, typed money and date columns, timestamps. Typed properly —
  `decimal` for money, `date` for dates.
  *Test:* migration runs up and down cleanly; model validations covered.

  Done 2026-09-22. Two migrations -- `CreateAimSchema`, then
  `CreateAimInvoices` -- plus `Aim::Record` (abstract, `table_name_prefix
  'aim.'`) and `Aim::Invoice`, tested in `test/models/aim/invoice_test.rb`.
  Worth carrying:

  - **Up and down proved in a scratch database**: `db/schema.rb` loaded,
    dumped back byte-identical, migrated, rolled back two steps to a dump
    identical to the original, and migrated again to the same result. The
    committed `schema.rb` diff is additive only -- `create_schema "aim"`,
    the table, the version.
  - **Do not make a scratch database with `RAILS_ENV=development`.** In
    development, `db:create` and `db:drop` act on the test database too, so
    dropping the scratch copy dropped `Paperboy_Test` with it. Recreated
    straight away (`RAILS_ENV=test bin/rails db:create db:schema:load`,
    stamped `test`, `GSAETL` owner), but next time use `RAILS_ENV=test` with
    `PAPERBOY_TEST_DATABASE` pointed at the scratch name, which touches
    nothing else. Never point either at `Paperboy_Dev`.
  - **`claimed_by` and `assigned_to` are strings**, because a claim today
    records the user's email and falls back to an employee id
    (`invoice_file_support.rb`). 5.5 dual-runs against those claims, so the
    column holds what they hold.
  - **`document_type` is free text, deliberately.** The Decisions list
    `Invoice`, `Memo`, `Credit`, `Coupon`, `Unknown`; the extraction worker
    actually emits `INVOICE`, `STATEMENT`, `CREDIT`, `UNKNOWN`. Validating
    either list would reject the other. See Open Questions.
  - **`state` is only required, not enumerated.** Its values are 5.4's.
  - `Subtotal` and `SalesTax` are not columns. They are still an open
    question, and adding a nullable column later is cheap.

- [x] **5.3 Migration: `aim.invoice_events`.** Append-only history. Who did
  what, when, from which state to which. This is the audit trail the
  pipeline has never had.
  *Test:* every state transition writes exactly one event.

  Done 2026-09-22. `aim.invoice_events` (`invoice_id`, `action`,
  `from_state`, `to_state`, `actor`, `note`, `created_at` only) and
  `Aim::InvoiceEvent`, which is read-only once written. Worth carrying:

  - **The event is written by `Aim::Invoice` itself**, in an `after_save`
    inside the same transaction, whenever `state` changes -- including the
    first state on create (`from_state` nil). So any path that changes state
    through the model writes exactly one event, and a failed event write
    rolls the state change back (tested).
  - **The caller names the actor on every change** (`invoice.update!(state:
    ..., actor: ...)`); a state change without one is invalid, and `actor`
    is cleared after each save so the next change cannot inherit it.
    Deliberately not read from `Current.user`: the workers have no session.
  - **The workers bypass all of this.** They write SQL, not Rails, so in 5.6
    each worker must insert its own event row in the same transaction as
    its state change. The model's guarantee covers Paperboy's side only.
  - **No database foreign key** -- see the rules under 5.1. An invoice with
    history cannot be deleted (`restrict_with_exception`); events cannot be
    edited or deleted at all.
  - `action` is `transition` for now; claims and assignments can become
    events of their own when 5.4 or 5.5 needs them.

- [x] **5.3a Teach the extraction worker the six document types.**
  `01_AI_Extraction_Worker` asked the models for `INVOICE`, `STATEMENT`,
  `CREDIT` or `UNKNOWN` and sent anything but an invoice to review. It now
  classifies all six, and only `Unknown` stops for QA review.

  Done 2026-09-22. `pipeline_common` owns `DOCUMENT_TYPES`,
  `DOCUMENT_TYPE_GUIDE` (the wording both prompts use, so the text pass and
  the vision pass cannot drift) and `normalize_document_type`. Worth
  carrying:

  - **One gate, one spelling.** `InvoiceData` normalises `document_type` on
    the way in, so `INVOICE`, `credit` and `'Coupon'` all become the decided
    spelling and anything off the list becomes `Unknown` rather than being
    guessed at. A payload written before today still reaches Laserfiche as
    `Invoice`, which is what `TemplateName` always title-cased it to.
  - **The models are confined to the six** by an `enum` in both the Phase 1
    schema and `VISION_SCHEMA`, which is now module level so the tests read
    the same schema the model is given. The fields stay plain strings, so an
    off-list answer is spelled rather than raising a hallucination error.
  - **The vision pass has the last word.** If Phase 1 says `Credit` and the
    vision pass cannot tell, the invoice goes to review -- unchanged
    behaviour, now stated.
  - **Laserfiche has no templates for the new types.** `TemplateName` is the
    type title-cased, so a Memo now arrives as template `Memo`. `Invoice`
    and `Unknown` are unchanged. Phase 11 owns the import mechanism; whoever
    designs it needs templates for all six, or a mapping.
  - **`Memo` and `Coupon` are described from guesswork.** The wording in
    `DOCUMENT_TYPE_GUIDE` is a first draft -- a memo as a payment memo or
    debit memo, a coupon as a remittance slip. Joshua corrects it from the
    manual testing; it is one constant to edit.
  - **Nothing in Rails can set a document type yet**, so AIM staff cannot
    resolve an `Unknown` on screen. The QA review screen needs a type
    selector -- see Open Questions.
  - *Not deployed.* `bin/deploy-aim-workers` has not been run; GSA-SCAN02
    still runs the four-type worker.

- [x] **5.4 `Aim::Invoice` model and state machine.** States enumerate the
  real queues plus the terminal outcomes. Illegal transitions raise.
  *Test:* the full transition table, including every rejection.

  Done 2026-09-22. 18 states -- the 15 queues the pipeline really uses, plus
  `archived`, `deleted` and `rejected` -- and a `TRANSITIONS` table naming
  every move. `transition_to!(state, actor:, note:)` raises
  `Aim::Invoice::IllegalTransition`; the same table is also a validation, so
  a bare `update` cannot make a move `transition_to!` would refuse. The test
  drives all 18 states against all 18: 56 moves allowed, **258 refused**.
  Worth carrying:

  - **The tests found two mistakes in the table as first written**, which is
    the argument for driving it exhaustively rather than testing a few
    paths. `rejected` was marked terminal, but the Rejected queue holds an
    invoice "awaiting archive or follow-up", so it can still be deleted or
    retried -- only `archived` and `deleted` are ends. And `action_needed`
    listed itself as a destination, because it shares the review exits.
  - **`error_queue` is a state**, though no screen shows it: a crashed batch
    really does land there, and a state machine that cannot express where
    the pipeline puts things is not modelling the pipeline.
  - **An invoice with an unsettled type cannot reach `user_approval`**,
    enforced as a validation, whichever route it takes. It may move
    anywhere else -- `Unknown` blocks the user's queue, not the pipeline.
  - **The document types are declared in two languages now**: Python's
    `DOCUMENT_TYPES` for the workers, `Aim::Invoice::DOCUMENT_TYPES` for
    Rails. `test/lib/aim/document_types_test.rb` reads the Python file and
    fails if the two lists disagree, since nothing else would notice.
  - Nothing writes these states yet. 5.5 has the screens read them, 5.6 has
    the workers write them; until then the pipeline still moves folders.

- [~] **5.5 Rails reads state from the database.** Queue screens and the
  work provider read rows, not directories. Files stay on the share as
  blobs. Dual-run against the folders during this step.
  *Test:* queue counts from the database match the folder counts.

  **Half done 2026-09-22, deliberately.** The counting half is built; the
  screens still read folders for what they show.

  - **`Aim::QueueSync` builds the rows from the share.** It adopts a folder
    with no row, records a folder that moved the way the pipeline moves it
    as that transition, and follows a folder somebody dragged as a `sync`
    event saying *folder moved outside the pipeline* -- three different
    things, told apart rather than averaged. It is idempotent, and a row
    whose folder has gone is counted, never moved: a worker may be part way
    through a move, and this class never decides an invoice has ended.
    **This is also the go-live cutover tool** from *Decisions → Database
    placement*: the rows can be rebuilt from the share at any time.
  - **The dashboard shows the database's count beside the folder's, and only
    when they differ.** Silence means they agree. It says nothing at all
    until something writes rows, and a database it cannot reach is logged
    and skipped -- the folders are still the truth this step, so AIM's
    screens must not go down with it.
  - **Rails' queue list was missing four directories** the state machine
    names: `pending_vision`, `ready_to_split`, `ready_to_delete` and
    `error_queue`. All four are real worker queues with variables already in
    LockBox; `PATH_ENV` simply never listed them.
  - **Adopting is not moving.** The rule that an untyped invoice may not
    reach `user_approval` now applies to a *change* of state, not to a new
    row, so a folder already sitting in the user queue can be recorded where
    it is. Refusing to write down where an invoice actually is would lose
    it, not protect anyone.

  **What is left of 5.5, and why it waits.** The queue screens read each
  invoice's vendor, number and total out of the JSON beside the PDF. The
  rows do not carry those yet -- the workers start writing them in 5.6 --
  so switching the screens now would empty them while Joshua is testing.
  The screens change once 5.6 fills the rows.

  **Nothing schedules the sync yet.** It runs from the console
  (`Aim::QueueSync.new.call`). Giving it a rake task or an admin button is a
  shared-config change (`lib/tasks/` or a route), so it goes to Joshua with
  Phase 6.2's `aim:import_vendors`, which needs the same permission.

- [~] **5.6 Workers write state to the database.** Each worker records its
  transition instead of implying it by moving a folder.
  *Test:* a full pipeline run through the fake tree produces the expected
  event sequence.

  **Code done 2026-09-22; not configured and not deployed.** `state_store.py`
  offers one call, `record_state(batch_id, state, actor, note)`, which writes
  the invoice row and its event in one transaction. All five workers call it
  -- 18 places in total: the watcher when an invoice is spooled, the AI
  worker at each of its eight routings and on a crash, the SQL worker on
  archive, failure, mapping bounce and deletion, the splitter and the alias
  learner on theirs. Worth carrying:

  - **A database that is not there does not stop the pipeline.** In this step
    the folders are still the truth, so refusing to move an invoice over
    bookkeeping would strand real work. The failure is printed, the move
    happens, and `Aim::QueueSync` rebuilds the rows afterwards. **That trade
    reverses in 5.7**, when the row becomes the truth.
  - **Saying it twice writes nothing.** A worker restarting mid-queue
    re-reads folders it already recorded; the store compares the state it
    finds before writing, so one move stays one event.
  - **Times are written `SYSUTCDATETIME()`**, because Rails reads these
    columns as UTC. `GETDATE()` would be the server's local time and every
    timestamp would be seven hours out.
  - **Table names come from `AIM_SQL_STATE_TABLE` and
    `AIM_SQL_STATE_EVENTS_TABLE`**, like every other AIM setting, and the
    connection from the `SQL_STATE` section that `get_sql_connection`
    already understands.
  - The sequence test runs a PDF through the watch tree and both workers with
    the models stubbed, and asserts the history: `ai_queue` by the watcher,
    then `sql_queue` by the AI worker, under one batch id.

  **What is left, and it needs Joshua:**

  1. **Which login the workers use.** The six new variables --
     `AIM_SQL_STATE_SERVER`, `_DATABASE`, `_USER`, `_PASSWORD`, `_TABLE`,
     `_EVENTS_TABLE` -- go to LockBox, and the worker `.env` lives on a share
     anyone who can reach `E:\AIM` can read. `GSAETL` is the standing
     choice and reaches everything; a login with rights on the `aim` schema
     alone would not. **Joshua decides; nothing is written to LockBox until
     he does.**
  2. **The deploy.** `bin/deploy-aim-workers --apply`, then restart the
     workers. Until then the fleet runs the 5.3a code and writes no rows.

- [x] **5.6a What the first night of recording found.** 2026-09-23, after
  19 invoices ran through the deployed workers overnight.

  - **It works.** 53 events, sequences right, actors named, timestamps in
    UTC: spooled by the watcher, routed by the AI worker, 15 archived by the
    SQL worker after reaching SQL, 4 sent to vendor review. GSA-SCAN02 can
    reach `GSASQL16`, which was the open risk.
  - **`_USER_APPROVAL` did not exist on the share.** Rails moves a corrected
    invoice into it and nothing had ever created it, because no worker reads
    it and `MANAGED_DIRECTORIES` therefore never listed it -- so the move
    failed on a share the workers otherwise keep in order. Added, with
    `_SPOOL_STATE`, which had the same gap (noted in Open Questions on
    2026-09-15 and now closed). **Needs a deploy to take effect.**
  - **The dashboard's dual-run note had a bug of my own making.** It showed
    the row count only when the queue had *some* rows, so Low Confidence --
    5 folders, no rows at all, the starkest disagreement -- said nothing.
    A missing key now counts as zero.
  - **Nine folders predated the wiring** (processed at 12:20, before the
    deploy) and so had no rows. `Aim::QueueSync` adopted them; folders and
    rows now agree exactly, which is 5.5's test passing against the real
    share rather than a temp directory.
  - **Counting shortcuts is not counting invoices.** `_ACTION_NEEDED` looked
    like it held two items; both were `.lnk` files. The screens were right
    all along -- they count directories -- but any tool of ours that counts
    entries has to do the same.

- [x] **5.6b Only a handwritten money amount goes to a person.** Found in
  testing 2026-09-23 on Incentive Services CV62744: every amount printed, an
  "OK to pay" and a signature beside them, and the invoice sent to Low
  Confidence as handwritten. Worse than one wasted review: the handwriting
  check returns before the vendor and missing-field checks, so the invoice's
  real problem -- no vendor name -- was never reported; and the flag latched
  across pages, so any document with a signature page was always flagged.

  The vision model no longer answers "is there handwriting?". It names which
  of `subtotal`, `tax` and `total` are handwritten
  (`handwritten_financial_fields`, confined by an enum), the prompt says in
  terms that signatures, initials, approval notes, dates and handwritten
  invoice or PO numbers do not count, and `InvoiceData` derives the flag from
  that list -- an empty list cannot raise it. The latch is now per money field,
  the union of every page. The ticket and the history name the fields. A
  payload written before the change, with no list, reads as it always did.

  13 tests (10 red without the change) drive the worker's real routing with
  the model stubbed, the CV62744 case among them. The pytest harness now
  refuses every database connection outright, since workers that record
  state would otherwise reach for SQL Server from a test. Needs a deploy;
  Joshua judges it on real documents.

- [ ] **5.7 Retire folder-as-state.** Remove `.claim.json`, remove the
  status-by-location inference, remove the Windows shortcuts.
  *Test:* the suite passes with no code reading a folder to learn status.

  Done in three parts, each safe to deploy alone: **(a)** the workers write
  the invoice's facts onto the row; **(b)** the screens read rows, and claims
  move onto the row; **(c)** the folder-reading code, the shortcuts and
  `is_urgent` go. Files stay on the share as the PDFs they are -- what goes is
  any code that *reads a folder to learn status*.

  - [x] **5.7a The row carries the facts.** 2026-09-23. `record_state` takes
    `fields`, built by `invoice_facts`: budget unit, submitter, document
    type, vendor (extracted and normalised), invoice/order/customer numbers,
    total, date, and the owner (`assigned_to`, `assignment_source`). The
    watcher writes the BU, submitter and owner at spool; the AI worker writes
    what it read at every routing; the SQL worker writes the final, corrected
    values at archive -- the same ones the billing row and the XML were built
    from. Three rules, each tested:
    - **A fact the caller does not know is never written**, so the AI
      worker, which knows nothing of the owner, cannot erase what the watcher
      recorded.
    - **A value that does not fit its column is dropped, not sent.** A total
      that is not money, a date that is not a date: SQL Server refusing one
      column would refuse the whole write, and with it the state.
    - **Column names come only from `FIELD_LIMITS`**, never from a caller or
      a document.
    Facts learned without a move update the row and add no event.
    `assigned_to` holds the folder's display name until 8b maps names to
    people. Found on the way: the SQL worker's **duplicate branch** archived
    a batch without recording it, so the row would have sat in `sql_queue`
    for ever; it now records `archived` with the reason. 227 pytest, 18 new
    and red without the change.

  - [x] **5.7b(1) Every move made on the screens is recorded, in the
    reviewer's name.** 2026-09-23. Sending to the SQL queue, to a user, to
    alias learning, back to Action Needed, rejecting, and an AI retry (the
    original recorded `deleted`, naming its retry folder) all record the move
    on the row, actor = the signed-in reviewer. `Aim::Invoice#record_move!`
    is shared with `Aim::QueueSync`: a move the pipeline makes is a
    transition; anything else is followed and written down as a `sync` event
    that says why -- never refused, because the file has already moved. A
    batch with no row is adopted. A database that will not record the move
    is logged and does not stop it; the sync puts the row right after.
    - **Claims are mirrored onto the row** (`claimed_by`, `claimed_at`) and
      released with the folder's; `.claim.json` stays the one that is read
      until 5.7c.
    - **An invoice typed `Unknown` cannot be sent to a user**, refused before
      anything moves. A document type corrected in the metadata grid is taken
      onto the row first, so the rule judges what the reviewer just set.
      Rows with no type at all -- adopted before 5.7a -- are let through and
      the event says so; refusing them would block every older invoice.
    - **Found and fixed: rejected invoices are nested**,
      `_REJECTED/<Submitter>_<BU>/<batch_id>`, and 5.5's sync would have
      adopted the group folder `Jane Doe_4601` as an invoice. It now reads
      that queue one level down.
    - The helpers moved into their own modules, `Aim::InvoiceStateRecording`
      (controller) and `Aim::InvoiceMoves` (model), which is where rubocop's
      length warnings pointed.
    10 controller tests (8 red without the wiring), 7 model tests, 1 sync
    test.

  - [x] **5.7b(2) The sync runs itself.** 2026-09-23. `Aim::QueueSyncJob`,
    every ten minutes, in `config/recurring.yml` (under the standing approval
    for AIM's own triggers: one added block, in `production`, which staging
    and development inherit). It catches what recording at every move cannot:
    a folder dragged by hand, a database down for a minute, a worker that
    crashed between moving a file and writing its row. Logs what it changed,
    and warns if folders and rows still disagree afterwards.
    **On a host where AIM is not configured it does nothing at all** -- not
    even a database query, since that host's database may have no `aim`
    schema. That matters because the schedule runs wherever Solid Queue
    does, teammates' machines included.

  - [x] **5.7b(3) The queue screens list what the rows say.** 2026-09-23.
    Which invoices a queue shows now comes from `aim.invoices`, not from
    listing a directory (`Aim::InvoiceQueueListing`). Nothing can drop out
    of sight in the change:
    - **A folder with no row is still listed**, with a *Not yet recorded*
      badge beside its status -- beside, not instead: a claim badge matters
      more, and the first version of this hid "Claimed by Dana Reyes".
    - **A row whose folder has gone is listed too**, as *Files not found on
      the share*, with no review link.
    - **If the rows cannot be read, the list comes from the folders** and the
      page says so.
    - **What each line shows is the folder's metadata first**, the row
      filling gaps. A reviewer's saved correction lives in the JSON until
      Phase 9 moves editing onto the row; showing the row first would show a
      value they had already fixed.
    - **Rejected lists invoices, not the `<Submitter>_<BU>` groups** it had
      been listing, and a rejected invoice now opens from its group folder --
      before, the review page could not find it at all.
    Claims are still read from `.claim.json`; 5.7c moves them.

  - [ ] **5.7c What 5.7c has to settle first** -- found 2026-09-23, before
    starting it:
    - **Two shortcuts are the only way to do their jobs.** Seven `.lnk`
      files sit in the queues. `MOVE_FOLDERS_HERE_TO_SPLIT` (Batch Split) and
      `MOVE_FOLDERS_HERE_TO_DELETE` (Action Needed, Low Confidence, Vendor
      Review) have no equivalent on the screens: there is no action to
      approve a split or to delete. The plan's "remove the Windows
      shortcuts" would break splitting and deleting. **The screens need
      Split and Delete actions first.** A drag onto a shortcut still works
      meanwhile, but the history can only say `queue_sync` moved it, not who.
    - **The row has no claimant's name.** The review page's banner says
      "Dana Reyes claimed this invoice"; `.claim.json` carries the name, the
      row only `claimed_by`. Reading claims from the row needs the name too --
      an additive `claimed_by_name` column, or a lookup by email.
    - **The inbox integration stays on folders.** `Aim::WorkProvider` reads
      queue folders and `.claim.json`, and it waits on the pfa refactor, which
      is not on master yet (checked 2026-09-23: master is 31 commits ahead,
      none of them pfa). It moves in 9.5; until then `.claim.json` cannot be
      retired outright, only stop being the one the screens read.
    - `is_urgent` can go from the workers, the payload and the Rails badge.

    **Decided with Joshua 2026-09-23:**
    - **Splitting gets a button, and must make sense.** It never had one in
      Paperboy -- no branch holds a split action; the earlier way was editing
      the manifest and dragging the folder onto the shortcut. The Batch Split
      review page shows the AI's proposed invoices, lets a person correct
      each one's pages (checked against the PDF's real page count, which
      `pdf-reader` -- already in the bundle through `prawn-templates` -- can
      read), add or remove one, and then **Approve Split**; or say **Not a
      batch -- process as one invoice**, which sends it back through
      extraction with the split check bypassed.
    - **Delete gets a button too**, so the `..._TO_DELETE` shortcuts can go.
    - **`claimed_by_name` goes on the row**, so claims are read from it.
    - **The inbox stays on folders until the pfa refactor lands**, and the
      user's AIM queue should eventually appear under **My Work** in
      Paperboy's inbox (9.5).

    **Found reading the splitter:** it takes the submitter from the batch
    id's third part, which is the file name, so every split invoice carries
    the wrong submitter and no owner; and it deletes the batch folder without
    recording what became of it, leaving the row in `ready_to_split` for
    ever. The fix is a terminal state, **`split`** -- the batch became the
    invoices named in its event -- and carrying the owner and BU through.

    **Order:** claims on the row; Delete; the `split` state and the splitter
    fixes; the Split screen; `is_urgent` out; then the shortcuts go.

  - [x] **5.7c(1) Claims are read from the row.** 2026-09-23. A new column,
    `claimed_by_name` (migration `20260923151741`), so the row can say who
    holds an invoice by name. The screens read the claim from the row first;
    the folder's `.claim.json` answers only when the row has none -- a claim
    made before rows carried them. The file is still written, because the
    Paperboy inbox reads it until 9.5. The queue list reuses the rows it
    already loaded rather than querying once per invoice. 4 new tests, all red
    without the change; 1039 runs, 0 fail, 0 error.

    Two things learned applying the migration:
    - **Never keep the `schema.rb` that `db:migrate` writes in development.**
      Migrating `Paperboy_Dev` re-dumps the schema from it, and that database
      carries other teams' newer migrations -- this time DAM access-rule
      tables and a version `20260923221136` our branch knows nothing of.
      Migrate the dev database, then `git checkout db/schema.rb`, and
      regenerate the schema from a scratch test database.
    - **At the next master merge, regenerate `schema.rb` from ours.** Master's
      latest migration (`20260922220000`) is newer than AIM's first three, so
      loading master's `schema.rb` would mark AIM's as run without running
      them -- the trap from 2026-09-22. Take our `schema.rb` on conflict, load
      it into a scratch database, and let master's newer migrations run on
      top.

  - [x] **5.7c(2) A Delete button.** 2026-09-23. Replaces the three
    `MOVE_FOLDERS_HERE_TO_DELETE` shortcuts. Offered on the review page
    wherever the state machine allows a move to `ready_to_delete`, so the
    button and the rules cannot disagree; refused anywhere else, the SQL
    queue included. It asks first, with the shared modal, and sends the
    folder to the delete queue, where the SQL worker archives it under its BU
    and submitter -- nothing is destroyed outright -- and the row records who
    sent it. No route change: like every other action on the page it is a
    named submit that `update` dispatches.

    **`238e7bd7` was pushed broken.** It declared `helper_method` inside
    `Aim::InvoiceQueueSupport`, which a unit test includes into a plain class;
    `helper_method` does not exist there, so the whole suite died at load
    time, before any test ran. The command that ran the gate went on to commit
    and push regardless, because nothing made the commit depend on the
    result. Fixed in the next commit by declaring it in the controller, and
    the gate is now checked before anything is committed: the result line
    must say `0 failures, 0 errors` and rubocop must say `no offenses`. The
    same fix moved the Send to Approval and Delete guards and the share
    write-failure handler out of the controller, which was over rubocop's
    length limit.

  - [x] **5.7c(3) A split batch keeps its owner and ends as `split`.**
    2026-09-23. A new end state, `split`, reached from `ready_to_split`: the
    batch's pages go on as new invoices in the reprocess queue, and the batch
    itself ends, its event naming the pieces. (`ready_to_split -> reprocess`
    is gone -- it was the pieces that went there, never the batch. "Process
    as one invoice" is `batch_split -> reprocess`, still allowed.) The sync
    skips every end state, since a split batch has no folder left.
    - **The owner travels with the split**: ticket -> AI worker (new `owner`
      argument) -> the manifest, which now carries `bu`, `submitter` and
      `owner` beside the invoices -> the splitter -> each piece's sidecar ->
      each piece's row, because the AI worker now records the owner itself.
      A piece or a retry reaches the AI worker without passing the watcher,
      so that is the only way its row learns who it belongs to.
    - **The splitter no longer guesses the submitter** from the batch id's
      third part, the file name. A manifest from before this change says
      `Unknown`, which is at least not wrong.
    5 tests with a real three-page PDF (4 red without the change). Needs a
    deploy.

  - [x] **5.7c(4) The Batch Split screen.** 2026-09-23. The review page for a
    batch shows the AI's proposed invoices as rows -- vendor, invoice number,
    pages written as people write them (`1-3, 5`) -- plus two blank rows for
    adding one; clearing a row's pages removes it. Two buttons:
    - **Approve Split** checks the plan (`Aim::SplitPlan`): every page a page
      of this PDF, counted by `pdf-reader`; every page in exactly one invoice,
      since a page left out would be lost and a page used twice paid twice;
      at least two invoices. A refused plan re-renders the page with the
      person's entries intact and each problem in plain words ("Page 2 is in
      invoices 1 and 2"), and nothing moves. An accepted one is written into
      the manifest -- keeping the BU, submitter and owner -- and the batch
      goes to the splitter.
    - **Process as One Invoice** sends the batch back through extraction
      with the split check bypassed and **its own batch id kept** (a new
      `processing_id` sidecar key the AI worker honours), so its history
      carries on; a plain retry is still minted a new id, as before.
    Found on the way: the page's old "AI Suggested Splits" summary had
    **never displayed** -- it looked for `Invoices` and the manifest writes
    `invoices` -- so reviewers had been shown raw JSON in a text box. And a
    blank invoice number would have reached the splitter as `null` and
    crashed it; blanks are now left out. The review page's setup moved into
    `prepare_review` so a refused split can re-render it. 12 checker tests,
    5 screen tests with a real PDF (5 red without the change), 2 worker
    tests for the kept id. Needs a deploy for the worker half.

  - [x] **5.7c(5) Action Needed can send to SQL, and urgency is gone.**
    2026-09-23.
    - **Action Needed offers Send to SQL Queue**, what its
      `MOVE_FOLDERS_HERE_TO_SEND_TO_SQL` shortcut did, and the path that works
      while the user approval queue is still to be built.
    - **`is_urgent` is removed** from the watcher's ticket, the AI worker (its
      argument, the urgent queue it sorted ahead of the rest, and the flag a
      retry used to set), `InvoiceData`, and the Rails "Urgent" badge. Jobs
      are processed oldest first. A payload or ticket written before this
      that still carries the key is simply ignored.

  - [x] **5.7c(6) The shortcuts are gone.** Every job they did now has a
    button: Delete, Approve Split, Learn Alias, Send to SQL Queue. Held
    briefly to tell staff, then released 2026-09-24: no staff use AIM yet,
    only Joshua while building it. `setup_shortcuts` and
    `create_windows_shortcut` are removed from `pipeline_common.py`, so
    `bootstrap()` plants nothing; `pywin32` leaves `requirements.txt`, as it
    had no other use. The seven `.lnk` files were deleted from the share
    the same day. The AI worker's `.ticket` notes now say to use Send to SQL
    Queue on the Paperboy review page instead of the SQL shortcut. A test
    proves `bootstrap()` leaves no `.lnk` behind.

---

## Phase 6 — Real Vendor Normalization

- [ ] **6.1 Migration: `aim.vendors` and `aim.vendor_aliases`.** Canonical
  vendors with an id, and many aliases pointing at one vendor. Vendors not
  present in Fiscal's list are flagged provisional.
  *Test:* model and association coverage.
  In the `aim` schema -- the name `aim_vendor_aliases` would have been the
  legacy `Aim_Vendor_Aliases` in `GSA_Scan`. Name the indexes explicitly.

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

## Phase 8b — Routing And Coding Before The Queue

Raised by Joshua 2026-09-23. **An invoice is not ready for a user until it
is coded and routed**, and the plan had both in the wrong place: account
coding sat in Phase 11, after approval, and routing had a column on the row
(`assigned_to`, `assignment_source`, from 5.2) but nothing to fill it. The
pipeline order is:

```text
extract -> normalise vendor -> check duplicates -> code and route -> user queue -> fiscal handoff
             (Phase 6)          (Phase 7)          (this phase)      (Phase 9)     (Phase 11)
```

- [x] **8b.0 The watch tree routes.** The watcher reads `/<BU>/<Name>/` as
  that person, `/<BU>/SHARED/` as the shared queue, ignores loose files at the
  BU root (skipping them before the unsupported-file rename), and drops the
  HIGH PRIORITY folder and the urgent flag. Owner recorded with
  `assignment_source = 'folder'`.

  Done 2026-09-23. `route_for` decides a folder's owner before a single
  file in it is looked at, so a loose file at the BU root -- the README
  included -- is skipped ahead of the unsupported-file rename. The job
  ticket now carries `queue` (`person` or `shared`), `owner` (the folder's
  name, or none) and `assignment_source = 'folder'`. The shared folder's
  name is `AIM_SHARED_FOLDER_NAME` (`SHARED`), added on LockBox `aim-config`
  (`891179b`, local only). Each BU folder gets
  `README - How to submit invoices.txt` from `BU_FOLDER_README.txt`, shipped
  with the workers; the watcher places it where missing and never over an
  edited one.

  - **Folders are named by display name** (`Joshua Gannon`, `Ryan Hill`,
    `Tryna Huebner` on the share today), which answers the open question and
    is why the name-to-person mapping on the admin screen matters.
  - **No HIGH PRIORITY folder existed**, so dropping it stranded nothing.
    `is_urgent` stays in the ticket, always false, because the AI worker's
    retry ordering and the Rails "Urgent" badge still read it; 5.7 removes
    the field when the payload becomes the row.
  - **The owner is in the ticket, not yet on the row.** `record_state`
    writes state only; 5.7 carries the ticket's owner into
    `aim.invoices.assigned_to`.
  - 18 tests, 17 red without the change.

- [ ] **8b.1 The rules table.** One table in SQL, replacing the lookup file
  PsiGen used. Each rule says *invoices matching this go there, coded thus*:
  - **matches** a Budget Unit, a vendor, or a vendor within a Budget Unit;
    the most specific rule wins;
  - **sends to** a shared BU queue (anyone with that BU sees it), a queue
    manager (who routes it on to a person), or a named person (only they see
    it) -- the three uses the old file's queue ids covered;
  - **codes it** with the chart-of-accounts fields `Aim_Invoices` already
    carries and nothing fills: `BDO_DO_CT`, `Program_Number`,
    `Major_Program`, `Fund`, `Object`, `Program`, `Activity`, `Function`,
    `Phase`, `Department`. Routing and coding share a row because the old
    file did; split them only if they turn out to vary independently.
- [ ] **8b.2 Apply the rules before the queue.** Every invoice passing the
  duplicate check gets its coding and its destination, with
  `assignment_source = 'rule'`. No match is an explicit outcome, not a
  silent blank -- which outcome is a question below.
- [ ] **8b.3 Admin screen for the rules**, with every change to a rule
  recorded. Assign a whole BU, or one vendor, to a queue or a person.
- [ ] **8b.4 Queue managers route onward.** A manager reassigning an
  invoice sets `assignment_source = 'manager'`; the event trail says who.

Supersedes 11.1, which put the coding after approval.

**Status 2026-09-23.** Joshua is copying the current lookups to a folder on
GSA-SCAN02 for evaluation. There are two groups, **GSA and Sheriff**; GSA
comes first. The lookups carry **QUEUE ID** numbers that correlate to
specific accounts. Sheriff has differences Joshua will explain, where vision
AI might help but earlier testing gave him reservations -- discuss before
designing anything for Sheriff.

**How an invoice gets an owner -- agreed with Joshua 2026-09-23.** Some
users scan with a PsiGen control sheet naming the queue id; the move is to
folder-based scanning, with scanners remapped to their BU folders on the
share.

```text
/<BU>/<Name>/        -> that person's queue       the default
/<BU>/SHARED/        -> the BU's shared queue     the rules table routes it
/<BU>/<loose file>   -> ignored                    each BU folder has a README
upload in Paperboy   -> the person or SHARED queue the uploader picks
```

- **The named subfolder is the person's queue.** Corrected the same day,
  after a first reading took it for the submitter only.
- **No HIGH PRIORITY folder, and no urgency at all.** Dropped by Joshua.
- **`SHARED` is a subfolder, not the BU root**, so a BU folder is a clean
  list of people plus one shared queue. Its name comes from a setting (like
  `AIM_SPLIT_FOLDER_NAME`), and it must not start with `_`, which the watcher
  prunes.
- **Loose files at the BU root are ignored**, and each BU folder carries a
  README explaining the layout. The watcher must skip the root *before* its
  unsupported-file check, which today renames anything not a PDF or image to
  `UNSUPPORTED_FILETYPE_...` -- otherwise it renames the README.
- **An explicit choice at import wins.** A named folder or an upload pick
  says who owns the invoice, and the rules table does not override it. The
  rules table routes only what arrives through `SHARED`, and it **codes
  everything**, however it arrived. Vendor lookup runs for all of them.
- **Why keep a shared queue:** coverage, so one person's absence does not
  stall their invoices; and a safe landing, so a folder name matching nobody
  lands where people look, flagged, rather than in a queue nobody watches.
- **Folder name to person** is resolved through a mapping on the rules admin
  screen, not by trusting the text. Still to ask Joshua how the folders are
  named.

**The GSA lookups, read 2026-09-23** (`\\gsa-scan02\aim\_Lookups\GSA`,
`/mnt/a/AIM/_Lookups/GSA`). Ten CSVs, about 790 rows, in three layouts: a
standard template (Vendor, AIM/Fiscal identifiers, Fund, Department,
Encumbrance Doc, Budget Unit, Object, Activity, Function, Program, Phase,
Task, Approver Name, often Fusion Queue and Keywords); an older one keyed on
BDO/PO # with a Fusion Queue column (4703, 4705, Housekeeping); and
Facilities, with only Vendor, Fund, Object, Program. What the data says about
the rules table:

- **Files are not BUs.** Business Support covers six (4601, 4621, 4641,
  4643, 4645, 4661); 4703 covers four; Fleet and Housekeeping two each. A
  rule carries its own BU; the file it came from is only provenance.
- **Queue ids are in most files but not all.** 62 and 75 (4703/4705), 92,
  119, 123, 198, 271, 300, 304 (Business Support), 313, 334, 30
  (Housekeeping), 254 (Parks). None in 4601, 4621, Fleet or Facilities --
  those route by something else, or not at all. Resolving an id to a person
  or queue needs Fusion's own tables.
- **One vendor, several rules, and the invoice decides which.** Housekeeping
  lists Vestis three times with a different customer number each
  (6063764, 6063751, ...) and a different BU or BDO. The AI already
  extracts `customer_number`, so **a rule may match vendor plus customer
  number**, and that is more specific than vendor alone.
- **Sometimes the invoice cannot decide.** 4703 lists 78 vendors more than
  once, typically the same coding on different BDO lines (`..._1`, `..._2`)
  with nothing on the invoice to tell them apart. That is a person's choice;
  the rules table offers the candidates to the router rather than picking.
- **Keywords are not to be trusted.** Joshua, 2026-09-23: they were an OCR
  aid and many are likely out of date. Not match keys; at most carried over
  as a note for a person to read.
- **Vendor codes (`VC000...`) are scattered** -- a Vendor Code column in
  Housekeeping, the *Fund* column in Fleet and Parks, the Keywords in
  Business Support. They are Fiscal's vendor ids, and Phase 6's vendor master
  wants them.
- **The import must validate, not guess.** Found so far: a person's name as
  a queue id (`DAVE`, four Security rows, beside a "Notes -Final Approver"
  column); a shifted row in Housekeeping where a quoted vendor name pushed
  `INC."` into the queue column and `30` into the BU; eleven blank vendor
  names in Parks; object codes with their description appended
  (`2192 TEMP HELP`); duplicated columns. Each becomes a reported row, never
  a silent guess.

**Fusion's own database, read 2026-09-23** (`Fusion01` on `gsa-sql22`,
read-only for `GSAETL` with `db_datareader` and `VIEW DEFINITION`). It is
the closest thing to a spec for the old routing:

- **A queue id is a Fusion user id.** Every user owns exactly one queue (120
  users, 120 queues), so the lookups' queue ids name people:

  | id | Fusion user | notes |
  |---|---|---|
  | 30 | Squires, Patrick | GSA H&G/Security |
  | 62 | Gagnon, Tonya | supervisor of GSA Maintenance -- all 291 rows of 4703 |
  | 92 | Payne, Sean | GSA H&G/Security |
  | 198 | Dixon, Charles | **disabled** -- ten Business Support rows |
  | 254 | Cooper, Jeri | GSA Parks |
  | 271 | Barley, David | GSA H&G/Security |
  | 300 | Martinez, Mark | GSA Business Support |
  | 304 | Howard, Gary | supervisor, GSA Business Support |
  | 313 | Bertrand, Brianna | GSA H&G/Security |
  | 334 | Salgado, Marcos | |
  | 75, 119, 123 | **no such user** | all of 4705, and rows in Business Support and Security |

  So the routing already points at people who have left or been disabled.
  The import has to map Fusion ids to Paperboy people (Fusion `Users` carries
  `EmailAddress` and `UserName`, which match GSABSS) and report every id that
  maps to nobody.
- **Teams carry a supervisor, a distribution setting and an aging rule.**
  GSA Business Support (supervisor Steve Nelles, 24 h), GSA Maintenance
  (Tonya Gagnon, 48 h), Sheriff AP (Katie Morgan-Peters, 72 h), GSA Fleet
  (Jorge Bonilla, 168 h), GSA Parks, GSA H&G/Security (Arturo Huizar), and
  others. The aging rule looks like escalation after an invoice sits too
  long -- a requirement the plan did not have. Ask Joshua what it does in
  practice.
- **Fusion's lookups are lists of valid values, not the routing.** Per
  document type (`GSA_AP`, `Parks_AP`, `Facilities_AP`, `Fleet_AP`,
  `Sheriff_AP`, `HCA_AP`, `PH_AP`, and RMA types), they query `GSA-Object`,
  `GSA-ActivityCode`, `GSA-DepartmentObject`, `GSA-Function`, `GSA-Phase`
  and `GSA-Program` through a connection named *GSA AP Codes*. Those lists
  are what the rules import should validate coding against -- `2192 TEMP
  HELP` is not an object code. They live in a database `GSAETL` cannot yet
  open.

**Answers and findings, 2026-09-23 (afternoon).**

- **Fusion users map to Paperboy people by employee number.** Fusion's
  `UserName` is the employee number (`139155`), the same number behind the
  `ENT\...` Windows logins and GSABSS `Employees.id`. Email does not match at
  all (0 of 11); employee number matches 9 of 11. The import keys on it.
  Every GSA match's `unit` is a BU from the lookups, which also confirms 9.1.
- **Queue corrections from Joshua:** `75 -> 335` (Christopher Stafford).
  Two problems to settle before import, both raised with Joshua:
  - **335 Stafford and 334 Salgado are not in GSABSS `Employees`**
    (employee numbers 139155 and 121550). Paperboy's sign-in requires an
    `Employees` row, so as things stand neither could log in to see an
    invoice routed to them.
  - **198 Charles Dixon is now in another agency** (CSSV, unit 2251), and his
    Fusion account is disabled. Joshua wrote "Charles should be changed to
    198"; 198 already is Charles, so what 119 and 123 become is still open.
- **Team distribution is not used** -- everything is assigned to a specific
  queue. Out of scope.
- **The valid coding values are in `bs_purchase_orders` on `gsa-sql22`**, an
  older database. Joshua wants them brought into AIM's own tables, next to
  everything else, where they are easier to manage. Read access for `GSAETL`
  requested; design the table once its shape is visible. Open: is
  `bs_purchase_orders` still maintained by someone? If so AIM keeps a synced
  copy; if not, AIM's copy becomes the one people edit.

**`bs_purchase_orders` compared with Paperboy's own chart of accounts,
2026-09-23.** `GSAETL` can now read it. Fusion's GSA lookups point at seven
tables there: single-column lists `GSA-ActivityCode` (6), `GSA-Function`
(56), `GSA-Phase` (5), `GSA-Program` (91), `GSA-DepartmentObject` (67),
`GSA-Object` (181: number, short name, "name and number"), and `GSA-Staff`.
In Fusion, Object and Activity apply the first match; Department Object and
Function make the user pick.

**Paperboy's chart of accounts already holds nearly all of it.** GSABSS
carries the county's full COA, agency-scoped (`Coa::` models: agencies,
units, funds, objects, activities, functions, phases, programs, major
programs, tasks), and it is maintained. Measured against agency `GSA`:

| List | Fusion | in COA | not in COA |
|---|---|---|---|
| Phase | 5 | 5 | -- |
| Activity | 6 | 5 | `6340` |
| Function | 56 | 53 | `0220`, `0250`, `SPLIT` |
| Program | 91 | 89 | `BUSAIM`, `BSCREATES` |
| Object | 180 | 176 | `4991`-`4994` |

Every GSA Budget Unit in the lookups is a COA unit too. **So AIM validates
coding against the COA and does not copy Fusion's value lists**, which is
what Joshua hoped for. The fifteen values it lacks are a review list, not a
reason to keep a second copy: `SPLIT` in particular looks like a marker for
split coding rather than a function. Note that the COA calls the agency `GSA`
while `Employees.agency` says `GSAV` -- two code systems for one agency, and
scope (9.1) has to map between them.

**`GSA-Staff` is the part the COA does not have** -- one row per GSA BU:
Fund (`G001`, `I200`-`I230`, `E400`, `E410`), a roll-up parent BU, the
budget name, the **Budget Manager**, the **First Approver** and the
**Accounting Officer**. It gives two things the rules table needs:

- **A BU-level default** -- the rule that applies when no vendor rule does,
  including the BU's Fund. `GSA-Staff` becomes the BU-level rows of the
  rules table; the CSV lookups become the vendor-level rows. One table, the
  most specific rule winning.
- **What looks like an approval chain**: first approver, budget manager,
  accounting officer. Whether approval is one step or several is a question
  for Joshua before Phase 9 designs it.

But it names people as text ("Rob Harris"), with the employee id filled in
for one BU of eighteen and the Fusion id for none, and some names repeat
across unrelated BUs. **Joshua, 2026-09-23: it is "years and years out of
date" and useless now. Not imported.** BU defaults are built fresh.

**Routing decisions, 2026-09-23 (evening).**

- **Every BU has a default route -- required.** Many invoices come from
  vendors in no lookup, and today each BU has a default queue for them. So a
  BU-level rule (destination plus default Fund) is mandatory for any BU that
  receives invoices; the admin screen flags a BU without one; an invoice that
  still matches nothing goes to AIM staff review with the reason, never
  nowhere. The first set of defaults is *proposed from the data* -- per BU,
  the queue most of its lookup rows already use -- for Joshua to confirm, not
  typed from scratch.
- **Approval is one step.** Joshua thinks there is no approval chain.
- **Amount thresholds are routing, applied after it.** Per BU, "totals over
  $X go to person Y". Resolved as a second pass: find the normal
  destination (vendor rule, else BU default), then the BU's thresholds
  replace it. **Joshua, 2026-09-23: above the threshold an invoice goes to
  the BU's threshold queue automatically** -- threshold and target set per
  BU. Read as overriding every other route, explicit folder and upload
  choices included, since that is what "automatically" is for; the history
  records both where it would have gone and why it did not.
- **Split coding is needed.** Joshua has seen invoices that must be charged
  to more than one account but does not know how it is done today. Proposed
  shape: an invoice has one or more **coding lines**, each an amount or
  percentage with its own Fund/Object/Program/..., and the lines must add up
  to the total before approval. Most invoices have one line. A rule may
  supply a default split for vendors that always split the same way; a user
  edits the lines at approval; every change is an event. `SPLIT` in Fusion's
  function list is probably the marker used today. Joshua: a split assigns
  dollar amounts to **more than one BU**, and how it is done today is not
  known here. **Blocked on Fiscal**, who Joshua will involve: how a split
  invoice reaches them now, and how it is recorded. It decides the coding
  lines' shape and Phase 11's export.

**Reminders instead of Fusion's aging -- Joshua, 2026-09-23.** Start with
email:

- **Daily**, when someone has new invoices to process.
- **Weekly**, for invoices that have gone stale in their queue.
- **Monthly**, always -- it cannot be turned off.
- Each person may turn the daily and weekly emails off; never the monthly.

Paperboy already sends a daily digest (`FormSubscriptionDigestJob`, 7am in
`config/recurring.yml`), and stores per-user preferences (`UserSetting`), so
this follows existing patterns and uses the standing approval for jobs and
schedules. Open: what counts as stale -- days since it arrived, or since
anyone touched it, and how many?

**Needed from Joshua before 8b.1:**

1. The old lookup file, or where it lives -- a few rows show the columns.
2. What the queue ids meant: which were people, shared queues, managers.
3. Who maintains the table: Joshua, AIM staff, or Fiscal.
4. What happens with no match: straight to review, or to the BU's shared
   queue with the coding blank for the user to fill?
5. Whether a user may change the coding at approval, as in PsiGen Fusion.

---

## Phase 9 — User Approval

- [ ] **9.1 BU access model.** Which users can see which Budget Unit queue,
  through Paperboy's existing groups and ACL. Follows the
  `AuthorizedApprover` pattern rather than reusing that table.

  **Scope comes from GSABSS, found 2026-09-23.** Sign-in matches the SSO
  account to an `Employees` row, and its `unit` column *is* the four-digit
  Budget Unit (4601, 4641 and 4721 carry 37, 22 and 35 employees); `agency`
  is the agency code (`SHFV`, `HSAV`, ...). GSABSS follows HR, so a transfer
  moves someone's scope with no upkeep. A person's scope is **their home unit
  from GSABSS, plus any extra BUs granted on the AIM admin screen** -- for
  fiscal staff who handle several BUs, or someone covering. Read GSABSS; never
  copy it.

  **Seeing a BU and receiving its invoices are separate** -- confirmed with
  Joshua 2026-09-23:
  - **Scope** (home unit plus granted BUs) decides which shared queues a
    person sees, and which BU pickers list them as someone to send to.
  - **Assignment always grants access to that one invoice**, whatever its BU.
    The rules table may route a BU's invoices, or one vendor's in any BU, to
    anyone; they then see exactly those invoices and nothing else in that BU.
  - So: grant the BU as scope when someone should work its shared queue;
    only assign when they should see just what is routed to them.
  - Crossing an agency boundary still needs the sender to hold
    `route_anywhere`; granting scope does not bypass it.

- [ ] **9.1a Capabilities, roles and scope.** Agreed with Joshua 2026-09-23.
  Three layers, reusing Paperboy's ACL rather than inventing a role system:
  - **Capabilities are AIM app features** in `AppFeature::FEATURES['aim']`,
    granted under ACL -> Application Features and checked with
    `can_use_app_feature?`: `approve`, `upload`, `route_within_bu`,
    `route_within_agency`, `route_anywhere` (admin), `manage_rules`. The
    routing ones are tiered; a higher one includes the lower.
  - **Roles are ordinary Paperboy groups** with a bundle of capabilities
    ticked -- AIM Approver, AIM Router (the old queue manager), AIM BU
    Manager, AIM Admin -- made in the ACL screen, with no code. Individual
    ticks cover the unusual cases.
  - **Scope says which BUs** (9.1). A capability means nothing until it is
    scoped: "route within BU" needs to know whose BU.
- [ ] **9.2 One user queue, with the document type on the face of it.**
  Decided with Joshua 2026-09-23, after first considering a second queue for
  the types that are acknowledged rather than approved: *"we don't need to
  have 2 types of queues, maybe just a clear tagging of the type of
  document."* So one `user_approval` state, and the screen shows what kind of
  document each row is -- an Invoice to approve, a Statement or Credit to
  note -- with the list filterable by type.

  This keeps the state machine as 5.4 built it: no new state, no second
  folder, and the type stays what Decisions says it is -- something that
  dictates terminal behaviour, not a separate pipeline. `Unknown` still
  cannot reach the queue at all, since a row with no type has no tag to show.

- [ ] **9.2a The queue has never worked.** It has never worked: the folder
  does not exist on the share, `user_approval` is missing from
  `BACKEND_QUEUES` so the screen redirects, and no worker reads the
  directory. See audit H1.
- [ ] **9.3 Approve, edit metadata, add notes.** With the event trail from
  5.3 recording each.

  **Parity with PsiGen Fusion, asked for by Joshua 2026-09-23:** a user at
  this screen can correct the metadata and write in a notes section, not
  merely approve or reject. Three things follow, and the last one is a
  question for Joshua rather than a detail:

  - **The row has to carry the metadata.** Today `aim.invoices` holds state
    and identity; vendor, number, total and date still live in the JSON
    beside the PDF. A screen that edits them needs them on the row, with the
    canonicalisation Phase 4 put in the workers applied to whatever a person
    types. That is 5.7's work, and this is now a reason it cannot be skipped.
  - **Every edit is an event.** `aim.invoice_events` already records who did
    what; an edit becomes an `edit` event naming the field, its old value
    and its new one, the way `AuditableEdits` does for Paperboy's forms. A
    note becomes a `note` event, which makes notes attributable and ordered
    rather than a field two people overwrite.
  - **Where approval sits in the pipeline is not settled.** Today an invoice
    goes `sql_queue -> archived`: the SQL row is written and the Laserfiche
    XML generated with nobody having looked at it. If a user may correct the
    metadata, that correction has to happen *before* the handoff, or the
    handoff has to be redone afterwards. See Open Questions.
- [ ] **9.4 Assignment.** `assigned_to` plus `assignment_source`, so a
  coversheet barcode can populate it later without redesign.
- [ ] **9.4a Upload through Paperboy.** Joshua 2026-09-23: *"a VERY VERY
  handy addition."* Drag and drop an invoice and send it to your own queue, a
  colleague's, or a SHARED queue. The picker lists what your scope and routing
  tier allow: the BUs you may send into, and within each its people plus its
  SHARED queue. It enters the **same intake as the watcher**, so batch ids,
  duplicate detection, image conversion and history behave identically; the
  difference is that the owner is a real Paperboy account rather than a folder
  name. The history records who uploaded it and who it went to, with
  `assignment_source = 'upload'`.

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

- [x] ~~**11.1 Populate the chart-of-accounts columns** from the vendor/BU
  lookup.~~ Moved to Phase 8b on 2026-09-23: coding has to happen before a
  user approves the invoice, not after.
- [ ] **11.2 The fiscal export** in the layout Fiscal specifies.
- [ ] **11.3 Stamp the metadata into the PDF.** Write the invoice's fields as
  custom PDF Info-dictionary keys at handoff, archiving the unstamped original
  first. See `## Decisions Already Made`.

  The fields are the ones `generate_laserfiche_xml` emits today plus the
  identity Phase 3 settles: vendor name, invoice number, invoice total,
  invoice date (the four-field business key), order number, customer number,
  budget unit, submitter, document type, `business_key` and `batch_id`. Key
  names use underscores for spaces, because that is how Laserfiche addresses
  them (`%(PDFmetadata_Vendor_Name)`).
  *Test:* a stamped PDF round-trips every field unchanged, punctuation and
  ampersands included; the archived original is byte-identical to what arrived.
- [ ] **11.4 Retire the Laserfiche XML.** Remove `generate_laserfiche_xml`, the
  `.xml` sidecar and the regeneration in `02_sql_worker.py` once 11.3 is
  proven in Laserfiche. This also retires the unconditional regeneration step
  1.3 introduced, and `TemplateName`, which becomes the stamped document type.

  `AIM_LASERFICHE_INBOX_PATH` survives the change but moves: it is the XML's
  `FolderPath` today, and becomes either a stamped key or the destination the
  finished PDF is written to. Decide which when 11.3 is written -- it stays a
  variable either way.
  *Test:* a full pipeline run produces no `.xml`, and nothing reads one.

---

## Where This Stands On The Server — 2026-09-22

Joshua confirmed AIM is **running nothing on GSA-SCAN02 right now**, and
asked for the workers to be updated and the back end cleared so he can drop
fresh invoices and test.

**Done:**

- **Every back-end queue is empty.** The 58 items in `_ACTION_NEEDED`,
  `_BATCH_SPLIT`, `_LOW_CONFIDENCE_REVIEW`, `_REJECTED`, `_SQL_QUEUE`,
  `_TEMP`, `_VENDOR_REVIEW` and the 39 `_SPOOL_STATE` markers were **moved,
  not deleted**, to `/mnt/a/AIM/_BACK_END/_PREVIOUS_TEST_DATA/2026-09-22/`.
  Clearing the spool markers matters: without it the watcher skips a file it
  has seen before, so re-dropping the same PDF would do nothing.

- **The workers are deployed.** 2026-09-22, 12:16. 22 files and a fresh
  `.env` (59 `AIM_*`, none discarded) to `/mnt/a/AIM/_PROGRAM`, replacing
  scripts dated 2026-09-10 -- so steps 3.1, 3.2, 4.1, 4.2, 4.3 and 5.3a are
  all on the server now, where before none of them were. The 22 replaced
  files are in `_PREVIOUS_SCRIPTS/2026-09-22`; `vendor_aliases.json` was
  left alone and still holds its 907 learned aliases.

  Two things the deploy exposed, both fixed on the way:

  - **The target was read with `grep` and came back unresolved.** LockBox's
    ROOT consolidation made `AIM_LINUX_QUEUE_BASE_PATH` read
    `${AIM_ROOT}/AIM`, so the deploy aimed at a directory literally named
    `${AIM_ROOT}`. It now reads values with `python-dotenv`, as the workers
    do. Two tests cover it; every earlier deploy test passed `--target`
    explicitly, which is how the resolution went untested.
  - **A WSL restart drops the mapped drives.** `A:` (`\\gsa-scan02\projects`)
    showed *Disconnected* in Windows and `/mnt/a` was empty, so the deploy
    refused -- correctly -- rather than write into an unmounted mount point.
    Touching the drive from Windows reconnects it (`cmd.exe /c "dir A:\"`),
    then `sudo mount -a` in a real terminal remounts it. `sudo` cannot
    prompt inside Claude Code's shell.

**Not done, and the next thing to do:**

- **The workers have to be started on GSA-SCAN02** --
  `START_ALL_SERVICES.bat`, a Windows-side action. The deploy only copies
  files and prints a reminder.

**Two decisions Joshua has not made yet:**

- **The processed originals stay for now.** `Invoices/_AI_Processed` (340
  files, 78M) and `Invoices/_Archive` (408 files, 66M) are last runs'
  documents. Not cleared -- say whether they should be.
- **The SQL rows stay for now.** `Aim_Invoices` and `Aim_Processing_Logs` on
  `gsa-sql22` hold 236 rows each, newest 2026-09-21. `GSAETL` may delete
  them. Say whether to.

**Worth knowing before testing:**

- **Drop test invoices in `/mnt/a/AIM/Invoices/<BU>/<Submitter>/`.** The
  watcher prunes any folder whose name starts with `_`, so the 89 PDFs in
  the `_SAMPLE INVOICES` folders are never ingested -- they are a library,
  not a queue.
- **The new `aim.*` tables stay empty this round.** The workers do not write
  them until 5.6, and the screens still read folders until 5.5. This round
  tests the pipeline, not the new state tables.

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
- ~~**5.1** Paperboy database or `GSA_Scan` for the new AIM tables?~~
  Answered: `GSA_Scan`. See `## Decisions Already Made`.
- ~~**AIM table names in `GSA_Scan`**~~ and ~~**rights for AIM's
  migrations on `gsa-sql22`**~~. Both found 2026-09-22 in 5.1 and both
  dissolved the same day by Joshua's decision to put the tables in the
  Paperboy database on `GSASQL16`, schema `aim`, as `GSAETL`.
- ~~**Document types disagree.**~~ Settled 2026-09-22 by Joshua: the
  Decisions list is right, plus `Statement`, and the worker's list is
  incomplete. `Unknown` is a temporary type AIM staff resolve in QA review.
  Step 5.3a.
- **Does approval happen before or after the handoff?** Raised 2026-09-23
  by Joshua's requirement that a user can edit the metadata at approval, as
  in PsiGen Fusion. Today the SQL worker writes the billing row and generates
  the Laserfiche XML as soon as extraction succeeds -- `sql_queue ->
  archived` -- so nobody has seen the invoice when it reaches Fiscal. Either
  the user queue moves ahead of that handoff, or an edit after it has to
  rewrite the SQL row and the Laserfiche document. The first is simpler and
  matches what approval means; the second keeps today's throughput. **Joshua
  decides; it shapes Phases 9 and 11.**
- **AIM staff cannot set a document type on screen.** Found 2026-09-22 in
  5.3a. `Unknown` is meant to be resolved in QA review, but nothing in
  `app/views/aim` edits `document_type` -- the reviewer can only edit the
  XML by hand. A type selector belongs on the review screen, wherever 5.5
  rebuilds it. Until then an `Unknown` has no supported way to become an
  `Invoice`.
- ~~**Which site should show live invoices once state is in the database?**~~
  Settled 2026-09-22 by Joshua: **the workers write `aim.invoices` in
  `Paperboy_Dev` while AIM is in development, and are switched to
  `Paperboy_Prod` at go-live** -- a LockBox value and a
  `bin/deploy-aim-workers`, no code. The legacy `gsa-sql22` tables are
  untouched either way. Consequences, all for 5.6 and go-live:
  - **Ordering.** The `aim` schema reaches `Paperboy_Dev` through the Phase 5
    merge and `bin/deploy-dev`'s `db:prepare` -- never a hand migration of
    the shared dev database. 5.6 comes after that.
  - **Cutover carries state over.** `Paperboy_Dev` will hold real in-flight
    invoices. At go-live they are copied to `Paperboy_Prod` or rebuilt from
    the share folders (5.5's folder reading can do the rebuild). Add to the
    go-live checklist.
  - **Credentials on the share.** The workers read `_PROGRAM/.env`, which is
    readable by anyone who can reach `E:\AIM`. Joshua's standing rule is
    `GSAETL` wherever possible, but it is the broad shared login; putting it
    there widens what that share exposes compared with today's
    `GSAScanCenter`. A login with rights on the `aim` schema alone is the
    narrower option. **Joshua's call, before 5.6.**
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
- **The workers run from a UNC path, so nothing may assume a working
  directory.** They are launched from `\\gsa-scan02\aim\_PROGRAM\`, and
  `cd /d` refuses to make a UNC path the working directory — cmd falls back
  to `C:\Windows`. On 2026-09-08 that made every worker fail with
  `python: can't open file 'C:\Windows\00_Ingestion_Watcher.py'`. Fixed by
  using `pushd` (which maps a temporary drive letter for UNC) in
  `_prepare_aim_environment.bat`, and by invoking python with
  `"%~dp0<script>.py"` so the working directory stops mattering. The bug was
  latent: the old share `.bat` files never called the preparer, and anyone
  running from a mapped drive letter would never see it. **Never add a
  relative path or a bare `cd` to a `.bat` here.**
- **A retried invoice does not keep its batch id.** Noted 2026-09-15 in 3.2.
  Retry names the copy `{id}_RETRY_{epoch}` and the worker mints a fresh id
  from that, so one document can hold three ids across its life. 3.2 fixed the
  Budget Unit inside those ids but deliberately did not make the id survive a
  retry, which is a design question rather than a bug: a retried document is
  arguably a new processing attempt of the same invoice. **Phase 7 needs an
  answer**, because the four-field business key is what catches duplicates and
  the batch id is what a reviewer follows through the queues. The same question
  applies to a split batch, which today gets `{parent}_SPLIT_{invoice}`.
- **`Subtotal` and `SalesTax` are not typed, not canonicalised, and not
  exported.** Noted 2026-09-21 in 4.3. `02_sql_worker` passes both to
  `InvoiceData`, which declares neither, so pydantic drops them; they survive
  only as raw strings in the payload dict, reaching SQL in whatever spelling
  Rails wrote and never reaching the Laserfiche XML at all. Neither is part of
  the four-field business key, so Phase 4 left them alone deliberately. Two
  questions for the fiscal handoff: **does Fiscal need them**, and if so are
  they money columns like the total, or free text? If they are money, adding
  them to `InvoiceData` and to `sanitize_data` is a two-line change now that
  `_clean_money` is right. `Aim_Invoices.Credit Amount` is the same question
  from the other end.
- **A credit is now stored with its sign, and nothing downstream reads it
  yet.** Noted 2026-09-21 in 4.3. `(100.00)` reaches SQL as `-100.00` instead
  of `100.00`, which is the correct number — but `Credit` is a document type
  with no queue behaviour of its own (see Decisions), and no rule says what a
  negative total should do at the approval gate or the fiscal handoff. Worth
  settling before Phase 9.
- **Nothing creates `AIM_SPOOL_STATE_DIR`.** Noted 2026-09-15 in 3.1. The
  watcher reads it at import and writes spool state into it, but it is not in
  `MANAGED_DIRECTORIES`, so `bootstrap()` does not create it -- the directory
  exists on the share already, which is why this has never been seen. A fresh
  environment would fail at the first spool. One line in `bootstrap` fixes it;
  out of scope for 3.1, and worth folding into whichever step next touches the
  watcher's startup.
- **The P2M OMS upload tests leave rows behind, and now fail on their own
  debris.** Seen 2026-09-15 during 3.1's gate and diagnosed during 3.2's.
  `OmsUploadLedgerTest#oms_number` and `P2mOmsUploadsControllerTest#oms_numbers`
  both build their OMS number as `5178<Process.pid % 10_000>`, and both
  `OmsUploadLedger#reconcile_imported!` and the controller's index scan
  `OmsUpload.all` rather than only their own rows. That alone made them collide
  at random. The real problem underneath is that **the rows outlive the test**:
  on 2026-09-15 `Paperboy_Test` held 82 committed `P2m::OmsUpload` rows from
  earlier runs that morning, so
  `P2mOmsUploadsControllerTest#test_shows_active_uploads...` now fails *every*
  run -- it reconciled `["51780767", "51784884"]` where it expected one id, the
  second being a leftover with a colliding mailer date.

  Not AIM's to fix: `test/controllers/p2m_oms_uploads_controller_test.rb` and
  `test/services/p2m/`. **Proved not ours by running the same test with AIM's
  entire diff stashed -- it fails identically.** Do that before treating either
  test as an AIM regression. Clearing the debris is
  `P2m::OmsUpload.delete_all` in the test environment, but the rows are P2M's
  and the leak is theirs to close.
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
| 2026-09-08 | 0.7 | (this commit) | `bin/deploy-aim-workers` added and run; 22 files + AIM-only `.env` deployed to `/mnt/a/_PROGRAM`; 36 pytest green |
| 2026-09-08 | — | 7c97bac7 | Merged master (26 commits, incl. Rails 8.1); pulled LockBox; launcher now restarts workers; redeployed |
| 2026-09-08 | — | (this commit) | Fixed UNC working-directory assumption in the launchers; redeployed; all five workers restart and run clean |
| 2026-09-08 | 0.8 | (this commit) | Configuration guard added and proved against planted literals; **Phase 0 complete**; 624 runs, 406 pass, 58 fail, 160 error |
| 2026-09-08 | — | `76a33ae` (LockBox) | LockBox `aim-config` merged to master and pushed; the twelve AIM variables are live for the team |
| 2026-09-08 | — | `8e4a6dda` | **Phase 0 merged to Paperboy master.** LockBox landed first, as the ordering requires |
| 2026-09-08 | 1.1 | (this commit) | `insert_sql_record` raises `SqlMappingError`; dead `env()` second argument fixed; 40 pytest green, Ruby suite unchanged at 624/406/58/160 |
| 2026-09-08 | 1.1a | (this commit) | Missing mapping file raises rather than skipping; 42 pytest green, Ruby suite unchanged |
| 2026-09-08 | 1.2 | (this commit) | Vendor-rule sidecar renamed `_VENDOR_RULE.json`; `metadata_path_for` prefers the payload; 629 runs, 411 pass, 58 fail, 160 error; 45 pytest green |
| 2026-09-08 | 1.2a | (this commit) | AIM controller tests unblocked (missing `employee_id` in the test session); 630 runs, 413 pass, 57 fail, 160 error |
| 2026-09-08 | 1.3 | (this commit) | One payload name (`PAYLOAD_SUFFIX`); SQL worker picks it explicitly; XML always regenerated, document type kept; 50 pytest green, Ruby suite unchanged |
| 2026-09-08 | 1.4 | (this commit) | Unarchived batches go to the failed queue instead of being deleted, duplicate path included; `import_worker` fixture added; 54 pytest green, Ruby suite unchanged |
| 2026-09-08 | 1.5 | (this commit) | Vision merges unified; risk flags latch instead of being discarded; 59 pytest green, Ruby suite unchanged |
| 2026-09-08 | 1.6 | (this commit) | Crash tickets file against the invoice that crashed; queue build order made deterministic; **Phase 1 complete**; 61 pytest green, 630 runs, 413 pass, 57 fail, 160 error |
| 2026-09-10 | — | `939a140f` | Merged master (19 commits: billing, P2M, forms) into the phase branch. Master's own errors rose 160 -> 190 in that window; measured on a clean `origin/master` worktree to confirm none of it is AIM's. Merged branch: 635 runs, 56 fail, 190 error -- six more tests and one fewer failure than master alone |
| 2026-09-10 | — | (this merge) | **Phase 1 merged to Paperboy master.** New baseline for Phase 2: 635 runs, 56 fail, 190 error (serial), plus 61 pytest |
| 2026-09-14 | 2.1 | (this commit) | Claims compare their owner; `update`/`retry`/`move_to_action_needed` refuse a foreign claim; `Errno::ENOENT` handled; 642 runs, 56 fail, 190 error -- same red set as the baseline |
| 2026-09-15 | — | `dca411a5` | **Phase 2 merged to Paperboy master.** 2.1 was its only step |
| 2026-09-15 | — | `88d5fc8b` | Merged `origin/master` (68 commits) into master. Their minitest repair clears the pre-existing red: **675 runs, 0 fail, 0 error**, plus 61 pytest. New Phase 3 baseline. rubocop is red on 81 non-AIM offenses |
| 2026-09-15 | 3.1 | (this commit) | One id per invoice: the watcher names the PDF after the batch id and the worker adopts the ticket's; ticket keeps `original_filename`; 69 pytest green, 722 runs, 0 fail, 0 error |
| 2026-09-15 | — | `b6f9ceed` | **3.1 merged to Paperboy master** by Joshua, ahead of the rest of the phase. Master then moved on three commits (rubocop autocorrect, sheriff-safety gitignore, HSA cards), merged into the phase branch before 3.2 |
| 2026-09-15 | 3.2 | (this commit) | Retry writes the reprocess sidecar and the worker reads it before minting the id, so a retried or split invoice keeps its Budget Unit; `Aim::ReprocessSidecar` added; **Phase 3 complete**; 72 pytest green, 733 runs, 0 error, 1 pre-existing P2M failure that is red with AIM's diff stashed too |
| 2026-09-21 | — | (this commit) | Merged `origin/master` (55 commits: digital asset management, publishing, records export) into the phase branch ahead of merging Phase 3 back. Their `rubocop -A` had rewritten the `Metrics/ClassLength` directive in AIM's controller test into `disable-next`, which this rubocop rejects; restored. `Paperboy_Test` was recreated 2026-09-19 and the `GSAETL` login has no access to it, so the suite ran on `PAPERBOY_TEST_DATABASE=Paperboy_Test0`, created by hand and left in place. **921 runs, 0 fail, 0 error** (serial), 72 pytest, scoped rubocop clean, brakeman's same four non-AIM warnings. New Phase 4 baseline |
| 2026-09-21 | — | (this commit) | `CONTROL ON DATABASE::Paperboy_Test` granted to `GSAETL`; access restored but the suite still cannot use it, because that database is stamped `development` and holds real DAM rows, so `db:test:prepare` cannot purge it and 111 DAM tests error. Staying on `Paperboy_Test0`, which is 921 runs, 0 fail, 0 error |
| 2026-09-21 | — | (this commit) | Default test database restored: `CONTROL` granted to `GSAETL`, then `Paperboy_Test` dropped and recreated clean and stamped `test`. `PARALLEL_WORKERS=1 bundle exec rake test` is **921 runs, 0 fail, 0 error** with no override; `Paperboy_Test0` dropped |
| 2026-09-21 | — | (this merge) | Merged `origin/master` (`2c45a370`, a `bin/deploy-dev` fix) then **merged Phase 3 to Paperboy master**. Gate green: 921 runs, 0 fail, 0 error (serial), 72 pytest, scoped rubocop clean, brakeman's same four non-AIM warnings. New Phase 4 baseline. Repo `.env` refreshed from LockBox the same day; see the backslash warning under *How configuration reaches the workers* before any worker deploy |
| 2026-09-21 | — | (this commit) | LockBox `019ca7c` pushed, quoting `AIM_WINDOWS_ROOT` so `python-dotenv` stops discarding it and `AIM_BASE_DIR`; repo `.env` refreshed, 59/59 `AIM_*` parse. `bin/deploy-aim-workers` now reads the rendered file with `python-dotenv` and refuses to deploy a discarded variable or a dangling interpolation, both proved by planted faults |
| 2026-09-21 | 4.1 | (this commit) | Vendor names keep their ampersand: `sanitize_data` strips and no longer rewrites, so the SQL row and the Laserfiche XML carry one value. Branch `aim/phase-4-keyfields` cut from master `f6bbc335`. 82 pytest green (6 of the 7 new tests red without the fix), 921 runs, 0 fail, 0 error, scoped rubocop clean, brakeman's same four non-AIM warnings |
| 2026-09-21 | 4.2 | (this commit) | Invoice and order numbers keep their punctuation: `_clean_text_field` filters control and invisible codes instead of a character class, and collapses whitespace. 107 pytest green (20 of the 25 new tests red without the fix), 921 runs, 0 fail, 0 error, scoped rubocop clean, brakeman's same four non-AIM warnings |
| 2026-09-21 | 4.3 | (this commit) | One spelling for a total: `_clean_money` keeps an accounting or trailing-minus sign, folds `-0.00`, and refuses a comma decimal rather than storing 1.23; `02_sql_worker` writes the sanitised values back into the payload so the row and the XML agree. **Phase 4 complete**; 130 pytest green (8 of the 23 new tests red without the fix), 921 runs, 0 fail, 0 error, scoped rubocop clean, brakeman's same four non-AIM warnings |
| 2026-09-21 | — | (this merge) | **Phase 4 merged to Paperboy master.** Master had not moved since the branch was cut from `f6bbc335`, so nothing needed merging in first. Gate green on the merge commit: 921 runs, 0 fail, 0 error (serial), 130 pytest, scoped rubocop clean, brakeman's same four non-AIM warnings. New Phase 5 baseline. Phase 5 needs Joshua's approval on the migration before 5.1, and the new `aim_*` tables mean a second Rails connection to `GSA_Scan` on `gsa-sql22` |
| 2026-09-22 | 5.1 | (this commit) | Branch `aim/phase-5-state` cut from `7cfeb98d`; baseline 921 runs, 0 fail, 0 error. Connection shape worked out and the `database.yml` diff proposed to Joshua, not applied. Two blockers found: `aim_invoices` collides with the legacy `Aim_Invoices` in case-insensitive `GSA_Scan`, and `GSAScanCenter` cannot create `AIM_Test` or any table |
| 2026-09-22 | 5.1 | (this commit) | **5.1 revised by Joshua:** new tables go in the Paperboy database on `GSASQL16`, schema `aim`, as `GSAETL`. Proved in throwaway databases: migrate, dump (`create_schema "aim"`), reload, typed decimal, unique index. Index names must be explicit. No shared config needed; 5.1a dropped; the earlier `database.yml` proposal is withdrawn |
| 2026-09-22 | 5.2 | (this commit) | Schema `aim` and `aim.invoices` created by two migrations; `Aim::Record` and `Aim::Invoice` added. Up/down proved in a scratch database; `schema.rb` diff additive only. `Paperboy_Test` dropped by a development-env `db:drop` and recreated at once. 931 runs, 0 fail, 0 error (serial), 130 pytest, scoped rubocop clean, brakeman's same four non-AIM warnings |
| 2026-09-22 | 5.3 | (this commit) | `aim.invoice_events` and `Aim::InvoiceEvent`; every state change through the model writes exactly one event, naming its actor, in the same transaction. No DB foreign key: the adapter dumps it without the schema and the resulting `schema.rb` cannot load; `schema_conventions_test` now guards that. 944 runs, 0 fail, 0 error (serial), 130 pytest, scoped rubocop clean, brakeman's same four non-AIM warnings |
| 2026-09-22 | 5.3a | (this commit) | Six document types, one spelling: `normalize_document_type` at `InvoiceData`'s gate, one prompt both models read, `enum` in both schemas, and only `Unknown` held back for QA review. AIM's migrations renumbered after a version collision with DAM's `20260922100000`. 160 pytest green (24 of the 30 new red without the fix), 944 runs, 0 fail, 0 error (serial), scoped rubocop clean, brakeman's same four non-AIM warnings |
| 2026-09-22 | — | (this merge) | Merged `origin/master` (2 commits: DAM stock photos, ResourceSpace import) into the phase branch. `db/schema.rb` conflicted and was regenerated from master's copy plus AIM's migrations rather than hand-merged. AIM's migrations renumbered a second time, above master's latest. 969 runs, 0 fail, 0 error (serial), 160 pytest, scoped rubocop clean, brakeman's same four non-AIM warnings |
| 2026-09-22 | — | (this commit) | Server prepared for a fresh test round: every back-end queue moved to `_PREVIOUS_TEST_DATA/2026-09-22` (58 items, spool markers included), watch tree left alone. **The worker deploy did not run** -- the permission classifier refused it -- so GSA-SCAN02 still runs the 2026-09-10 scripts |
| 2026-09-22 | — | (this commit) | **Workers deployed** to `/mnt/a/AIM/_PROGRAM`: 22 files plus a fresh `.env`, replacing 2026-09-10 scripts, so Phases 3-4 and step 5.3a now run on the server. Deploy target resolution fixed to read `${VAR}` references through `python-dotenv`; 162 pytest green |
| 2026-09-22 | 5.4 | (this commit) | `Aim::Invoice` state machine: 18 states, 56 allowed moves, 258 refused, enforced by both `transition_to!` and a validation. Exhaustive table testing caught `rejected` wrongly marked terminal and `action_needed` pointing at itself. Ruby/Python document type lists tied together by a test. 992 runs, 0 fail, 0 error (serial), 162 pytest, scoped rubocop clean, brakeman's same four non-AIM warnings |
| 2026-09-22 | 5.5 | (this commit) | `Aim::QueueSync` makes the rows say what the share says -- adopting, transitioning, or recording an out-of-band drag as a `sync` event -- and the dashboard shows the database's count beside the folder's when they differ. Four missing queue paths added. The screens still read folders for content until 5.6 fills the rows. 1004 runs, 0 fail, 0 error (serial), 162 pytest, scoped rubocop clean, brakeman's same four non-AIM warnings |
| 2026-09-22 | 5.6 | (this commit) | `state_store.record_state` and 18 call sites across all five workers: every move now says where it came from and who made it. Failure to write never blocks a move while the folders are still the truth. 177 pytest green (5 of the new sequence tests red without the wiring), 1004 runs, 0 fail, 0 error (serial), scoped rubocop clean, brakeman's same four non-AIM warnings. Not configured, not deployed: the login is Joshua's call |
| 2026-09-23 | — | (this commit) | **Restored the plan.** `89a96f7a` truncated it at the routing note -- a scripted replacement kept the text before the paragraph and dropped everything after, losing Phases 9-11, the server status, Open Questions and this log. Rebuilt from `22ea0c27` and the day's decisions reapplied: SHARED subfolder, no urgency, loose files ignored, upload through Paperboy, capabilities as AIM app features, roles as groups, scope from GSABSS `unit` |
| 2026-09-23 | 5.6b | (this commit) | Handwriting flag follows the money fields the model names, not a yes/no; signatures and notes no longer send clean invoices to review; latch per field across pages. 191 pytest green (10 of 13 new red without the change); tests now refuse all database connections |
| 2026-09-23 | 8b.0 | (this commit) | The watch tree routes: named folder = that person, `SHARED` = the BU's shared queue, loose files at the BU root ignored before the unsupported-file rename, no HIGH PRIORITY. README per BU folder. `AIM_SHARED_FOLDER_NAME` on LockBox `aim-config` (`891179b`, local). 209 pytest green (17 of 18 new red without the change) |
| 2026-09-23 | 5.7a | (this commit) | Workers write the invoice's facts to the row with each move: BU, submitter, owner, type, vendor, numbers, total, date. Unknown facts never overwrite known ones; ill-fitting values dropped; column names only from a whitelist. SQL worker's duplicate branch now records its archive. 227 pytest (18 new, red without the change), 1004 runs, 0 fail, 0 error |
| 2026-09-23 | 5.7b(1) | (this commit) | Every move made on the queue screens recorded on the row in the reviewer's name; claims mirrored onto the row; Unknown-typed invoices refused before they reach a user; nested rejected folders synced correctly. 1022 runs, 0 fail, 0 error, 227 pytest, scoped rubocop clean |
| 2026-09-23 | 5.7b(2) | (this commit) | `Aim::QueueSyncJob` every ten minutes via `config/recurring.yml`; a no-op, database included, where AIM is not configured. 1026 runs, 0 fail, 0 error |
| 2026-09-23 | 5.7b(3) | (this commit) | Queue screens list invoices from the rows, with folders that have no row and rows that have no folder both still shown and flagged; folder listing when the rows are unreadable. Rejected lists invoices, not groups, and opens them. 1035 runs, 0 fail, 0 error |
| 2026-09-23 | — | (deploy) | **Workers deployed** by Joshua at 15:12: 24 files and a 66-variable `.env`, verified identical to the repo. Carries 5.6b (handwriting), 8b.0 (watch tree, README, SHARED) and 5.7a (facts on the row). Replaced files in `_PREVIOUS_SCRIPTS/2026-09-23_151211`. Workers need a restart on GSA-SCAN02; `SHARED` folders still to be created |
| 2026-09-23 | 5.7c(1) | (this commit) | Claims read from the row, with the claimant's name in a new `claimed_by_name` column; `.claim.json` still written for the inbox. `Paperboy_Dev` migrated. 1039 runs, 0 fail, 0 error |
| 2026-09-23 | 5.7c(2) | (this commit) | Delete button on the review page, offered where the state machine allows it and refused elsewhere; archives rather than destroys; recorded in the reviewer's name. 1042 runs, 0 fail, 0 error |
| 2026-09-23 | 5.7c(2) | (this commit) | **Fix for `238e7bd7`, pushed with a suite that crashed at load time** (`helper_method` in a module a plain test class includes). Declared in the controller; guards and the write-failure handler moved out of it. Gate now checked before committing. 1042 runs, 0 fail, 0 error, rubocop clean |
| 2026-09-23 | 5.7c(3) | (this commit) | `split` end state; the splitter records the batch as split naming its pieces, reads BU/submitter/owner from the manifest instead of guessing from the file name, and hands the owner to every piece. 1042 runs, 0 fail, 0 error, 232 pytest, rubocop clean |
| 2026-09-23 | 5.7c(4) | (this commit) | Batch Split screen: Approve Split (checked against the PDF's page count; refused plans re-render with the person's entries and plain errors) and Process as One Invoice (keeps its batch id). Found the old split summary never displayed. 1059 runs, 0 fail, 0 error, 234 pytest, rubocop clean, brakeman unchanged |
| 2026-09-23 | 5.7c(5) | (this commit) | Action Needed gets Send to SQL Queue; `is_urgent` removed from watcher, AI worker, payload and Rails badge. Shortcuts held until Joshua has told staff. 1060 runs, 0 fail, 0 error, 234 pytest, rubocop clean |
| 2026-09-24 | 5.7c(6) | (this commit) | Shortcuts retired: the workers no longer plant them, `pywin32` dropped, the seven `.lnk` files deleted from the share, ticket notes point to the Send to SQL Queue button. Released early because no staff use AIM yet |
