# Paperboy (Ventura County Forms App)

**Ruby version:**

```bash
ruby 4.0.6
```

**Rails version:**

```bash
Rails 8.0.2
```

Paperboy is a Ruby on Rails 8.x application for managing internal forms (e.g.,
Parking Lot Submissions, Probation Transfer Requests, Safety Reporting, etc.)
with a modernized workflow. It integrates with Microsoft SQL Server and uses
Solid Queue for background jobs, Solid Cache for Rails.cache, and Solid Cable
for Action Cable.

For the product story / sales pitch, see the
[Pitch](http://10.135.204.125:3000/BSS/Paperboy/wiki/Pitch) wiki page.

## Gitea workflow

Paperboy's issue, pull request, milestone, Project, and automation conventions
are documented on the
[Gitea Workflow](http://10.135.204.125:3000/BSS/Paperboy/wiki/Gitea-Workflow)
wiki page. Use the repository's Gitea templates when opening an issue or
pull request.

### Command-line workflow

Set `GITEA_TOKEN` in the environment or in the ignored `.env.local` file.
Never commit the token. `bin/env-pull` replaces `.env` from LockBox, which
keeps that token empty. Create an issue before starting implementation.
The body follows the matching file in `.gitea/issue_template/`.
`--answers-file` is JSON keyed by the section ids from
`bin/new-issue --type feature --fields`.

```bash
bin/new-issue --type feature \
  --title "Short imperative title" \
  --answers-file /path/to/answers.json
```

A pull request body follows `.gitea/pull_request_template.md`.
`--answers-file` uses the section ids from `bin/create-pull-request --fields`.

```bash
bin/create-pull-request \
  --title "Short imperative description (#123)" \
  --head issue/123-short-description \
  --answers-file /path/to/answers.json
```

Create the issue-linked branch and worktree:

```bash
bin/worktree create issue/123-short-description
cd "$(bin/worktree switch issue/123-short-description)"
```

Use only branches matching `issue/<number>-<lowercase-slug>`. Review the
repository status with:

```bash
bin/status-report
```

After review and merge, clean up the local worktree and branch:

```bash
git switch master
git pull --ff-only
bin/worktree cleanup issue/123-short-description
```

`bin/update-issue` can apply an explicitly approved title, body, label,
milestone, project, or column change. It previews changes unless `--apply`
is supplied. A body uses the same `--type` and `--answers-file` as
`bin/new-issue`, and `--type` sets that type label. `--label`,
`--add-label`, and `--remove-label` refuse bug, feature, chore, and
infrastructure. `--project` replaces
the issue's project list. `--column` moves the card with the issue's
global id. The same milestone, project, or column is left unchanged.
The command does not close the issue.

```bash
bin/update-issue --issue 123 --add-label priority:normal
bin/update-issue --issue 123 --title "Short imperative title" \
  --type feature --answers-file /path/to/answers.json
bin/update-issue --issue 123 --add-label priority:normal --apply
```

For interactive shells, source `bin/shell-init` once to add the `wt` helper.
Then `wt 123` changes directly to the issue worktree; `bin/wt 123` remains a
path-producing command for scripts and command substitution:

```bash
source /path/to/Paperboy/bin/shell-init
wt 123
```

For command options, prompting behavior, and safety rules, see the
[Gitea Workflow](http://10.135.204.125:3000/BSS/Paperboy/wiki/Gitea-Workflow)
wiki page.

---

## Versioning

The current release line is controlled by the root [`VERSION`](VERSION) file,
which contains only `major.minor.patch`, for example `2.0.1`. Update that file
in the same commit as the change that warrants a version bump:

- major: incompatible API or workflow changes (`3.0.0`)
- minor: backward-compatible features (`2.1.0`)
- patch: backward-compatible fixes (`2.0.2`)

After a successful CI run, every push to `master` receives an annotated tag such
as `v2.0.1-21df93052`, where the suffix is the first nine characters of the
commit SHA. The application displays the same value centered along the bottom
of every page.
The displayed value is `VERSION` plus the checked-out commit, read from git, so
it always names the code that is running. For packaged deployments that do not
include `.git`, set `PAPERBOY_VERSION` to the full numeric version and optional
commit suffix. Leave it unset everywhere else: it overrides the commit, and
`bin/tag-master-commit` does not write it.

To create the same tag manually after updating `VERSION`, check out the commit
that should be released and run:

```bash
bin/tag-master-commit
```

The script uses `GITEA_SHA` or `GITHUB_SHA` when CI provides it,
otherwise it tags `HEAD`.
Pass a commit explicitly when needed: `bin/tag-master-commit COMMIT`. It is
safe to rerun when the tag already exists on the remote.
---

## Local development

Running Paperboy on your own workstation. This is **not** a deployment —
do not use `bin/deploy-dev` here. That script checks out `master`,
precompiles assets and restarts systemd units that only exist on the dev
server; on a workstation it resets your branch, leaves precompiled assets
shadowing your live edits, and then fails at the `systemctl` calls.

### First-time setup

Ruby is pinned in `mise.toml`. Install it and hook mise into your shell —
the `echo` line is run once, `.bashrc` sources it on every shell after
that:

```bash
mise install
echo 'eval "$(mise activate bash)"' >> ~/.bashrc
exec bash
ruby -v            # expect 4.0.6
```

Do not `apt install ruby-bundler` or `snap install ruby`. Both put a
second Ruby on `PATH` ahead of mise's and the pin stops meaning anything.

System packages (Ubuntu):

```bash
sudo apt install build-essential libyaml-dev libffi-dev \
                 freetds-dev freetds-bin
```

`freetds-dev` backs the `tiny_tds` gem. Then:

```bash
bundle install
```

### The .env file

Environment variables come from two gitignored files:

| File | Holds | Maintained by |
|------|-------|---------------|
| `.env` | a verbatim copy of `LockBox/Paperboy.env` | `bin/env-pull` — never edit it by hand |
| `.env.local` | what belongs to this machine or to you | you; nothing ever overwrites it |

Creating or opening a worktree copies a missing `.env` and `.env.local`
from the shared checkout. A file already in the worktree stays as it is.

dotenv reads `.env.local` first and the first value wins, so a name set in
both takes its value from `.env.local`. If a value is the same for everyone
it belongs in LockBox; otherwise it goes in `.env.local`.
`.env.local.example` lists the usual candidates — `PAPERBOY_DATABASE`,
`PAPERBOY_TEST_DATABASE`, `GSABSS_HOST`, `DEV_EMAIL`, `KRB5CCNAME`.

```bash
bin/env-pull             # pull ~/gitea/LockBox, replace .env
bin/env-pull --check     # report what would change, write nothing
bin/env-pull --no-pull   # copy from the LockBox checkout as it stands
bin/env-pull --prune     # accept losing variables LockBox does not have
```

It prints the names of the variables added, changed and removed, never
their values, and keeps the file it replaced as `.env.previous`. A variable
that is in the current `.env` but in neither LockBox nor `.env.local` would
vanish, so the copy is refused until you move it to `.env.local`, add it to
LockBox, or pass `--prune`. The LockBox checkout is `--lockbox <dir>`, then
`$LOCKBOX_DIR`, then `../LockBox`.

`bin/deploy-dev`, `bin/deploy-stage` and `bin/deploy` run `bin/env-pull`
right after checking out the code, so the hosts pick up LockBox changes on
their own and a refused copy stops the deploy before anything has changed.
`NO_ENV_PULL=1` deploys with the `.env` already there. The systemd units
load `.env.local` ahead of `.env` the same way Rails does, and — unlike
stock dotenv — so does the test environment, which is where
`PAPERBOY_TEST_DATABASE` is read.

`config/database.yml` uses `ENV.fetch` with no defaults, so Rails will not
boot without `.env`. At minimum:

```bash
# Define simple ROOTS alphabetically here. Define all other roots within their
# respective sub-application locations using these roots.
AIM_ROOT=/mnt/a
GSABSS_ROOT=/mnt/i
HSA_ADOPT_ROOT=/mnt/a
P2M_ROOT=/mnt/o

# Primary SQL Server connections
#GSABSS_HOST=GSASQL16
GSABSS_HOST=10.135.204.161
GSABSS_PORT=1433
GSABSS_USERNAME=
GSABSS_PASSWORD=
GSABSS_TIMEOUT=5
GSABSS_DATABASE=GSABSS
PAPERBOY_DATABASE=Paperboy_Dev

# P2M
P2M_DATARUNNER_ROOT=/mnt/o/Outputs/DataRunner
P2M_SHIPPING_STATION=00_ShippingStation
P2M_STAGING=01_Staging
P2M_TEMPORARY_OUTPUT=02_TemporaryOutput
P2M_PROCESSED=03_Processed
P2M_DESTROYED=04_Destroyed
P2M_PRINTERS=99_Printers
SMB_USERNAME=
SMB_PASSWORD=
SMB_IP=
PAPERBOY_DATABASE=Paperboy_Dev

# Active Record
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=

# SMB Shortcut
SMB_USERNAME='ENT\000000'
SMB_PASSWORD='password'

# GITEA
GITEA_URL=http://10.135.204.125:3000
```
`PAPERBOY_DATABASE` is read in every environment, not just development —
`config/database.yml` uses it as the database name for development, staging
and production alike. The stage host overrides it back to `Paperboy_Stage`
in its systemd units and in `bin/deploy-stage`; see "Stage has its own
database" below. Copying a dev `.env` onto a server without that override
points that server at dev's data.

The three encryption keys must match the values used elsewhere or
existing encrypted columns will not decrypt. Add `ENTRA_*`, `METABASE_*`,
`POWERBI_*`, `TEAMS_WEBHOOK_URL`, `AIM_*` and `BILLING_ARCHIVE_ROOT` as
the area you are working on needs them.

### Running it

```bash
bin/dev-local            # Puma on :3001 + Solid Queue + Dart Sass, one terminal
bin/dev-local 3005       # different port
bin/dev-local --cron     # also run the scheduled jobs
bin/dev-local --no-jobs  # Puma and Sass only
```

It preflights `.env` and the port, stops Paperboy processes already running
from this checkout, prepares the asset build, and starts Puma, Solid Queue,
and the Sass watcher in the background. Logs are written to `log/`:
`assets.log`, `server.log`, `jobs.log`, `sass.log`, and `error.log`.

`bin/dev` is the same script — it passes its arguments straight through, so
either name starts the same three processes.

### Two things to know

**Application data has no local database.** `development` connects to whatever
`PAPERBOY_DATABASE` names on the shared SQL Server, so this machine needs
network access to it. Point it at a database of your own rather than
`Paperboy_Dev`, where anything you write is visible to everyone on dev, and
never at one the test suite uses — `rake test` reloads the schema into
`PAPERBOY_TEST_DATABASE` and would take your data with it. Avoid `bin/setup`
— it runs `db:prepare`, which would migrate the shared database.

`bin/dev` sets `PAPERBOY_LOCAL_SOLID=1`. Puma and Solid Queue then store
Solid Queue, Solid Cache, and Solid Cable in SQLite files under this
checkout's `storage/` directory. Each worktree has its own files. The dev
server, staging, and production leave the variable unset, so their Solid
tables stay in the primary Paperboy database. A console or `bin/jobs`
started without the variable uses that shared database too.

**Scheduled jobs are off by default.** `bin/dev-local` sets
`SOLID_QUEUE_SKIP_RECURRING=true`, because the recurring schedule is loaded by
the Solid Queue scheduler. Left on, a workstation runs
`OshaReportableDeadlineJob` hourly against `Paperboy_Dev`, and that job
writes `reportable_breach_notified_at` as its dedupe stamp — so it would
race the dev server and consume notices the server should have sent. Pass
`--cron` only when you are deliberately testing a scheduled job. Servers
never set the variable and keep their schedule.

DAM watch folders are swept by one of those recurring jobs, so a file dropped
into one on a workstation is only ingested under `--cron`. Without it, sweep
by hand with `bin/rails dam:ingest_watch_folders`.

### Running tests

The test suite uses SQL Server. It is not a SQLite test suite: the models,
schema, SQL Server adapter behavior, and shared GSABSS connection are all part
of the tests. The test connection uses `GSABSS_HOST`, `GSABSS_PORT`, and the
same credentials as the other SQL Server connections.

`config/database.yml` defaults the test database to `Paperboy_Test`. To use a
temporary replacement database, set `PAPERBOY_TEST_DATABASE` for the command:

```bash
PAPERBOY_TEST_DATABASE=Paperboy_Test0 bundle exec rake test > output.log 2>&1
```

The named database must already exist, and the SQL login must be able to create
and drop databases and load the schema. Tests run in parallel. Rails creates a
separate schema-loaded database for each worker by appending a random run
identifier and worker number to the configured base name, then drops those
worker databases after the run. Do not use a shared development database as
the test base.

If `GSASQL16` does not resolve from the workstation, set `GSABSS_HOST` to
`10.135.204.161` in `.env` or for the command. Keep the test database and
worker databases isolated from development and staging data.

### Logging in

Entra's callback is `/auth/callback`, which is not registered for
`localhost:3001` in the app registration, so OAuth will not complete
locally. Use the impersonation route instead: `POST /login`
(`sessions#create_legacy`) takes an employee id.

### Assets

Development compiles assets on demand through sprockets. Leave
`public/assets` empty — if you ever run `assets:precompile` locally those
files shadow your SCSS and JS edits until you run `assets:clobber`.

---

To run Solid Queue directly during development, set the same variable
`bin/dev` sets. Without it, this worker claims jobs from the shared
`Paperboy_Dev` queue:

```bash
PAPERBOY_LOCAL_SOLID=1 bundle exec bin/jobs
```

## Dev deployment systemd - Only PUMA restart

```bash
sudo systemctl restart paperboy-dev

# Deploying with git pull, bundle install, pre-compile, puma restart, Solid Queue restart
bin/deploy-dev

# Check Logs
sudo journalctl -u paperboy-dev -f
sudo journalctl -u paperboy-dev-jobs -f

# Stop temporarily (e.g. to run rails s manually)
sudo systemctl stop paperboy-dev

# When done:
sudo systemctl start paperboy-dev
```

## Stage Deployment

  Restart Puma (just Puma):

```bash
sudo systemctl restart paperboy-stage
```

  Restart both (Puma + Solid Queue):

```bash
sudo systemctl restart paperboy-stage paperboy-stage-jobs
```

  Full deploy (git pull → bundle → assets:clobber → assets:precompile → restart both):

```bash
bin/deploy-stage              # deploys master
bin/deploy-stage some-branch  # deploys a different branch
```

  It mirrors bin/deploy-dev exactly, except it runs RAILS_ENV=staging, bundle
  install --without development test, and restarts the paperboy-stage* units.
  The script prompts for your sudo password during the two systemctl restart
  calls near the end.

### Stage has its own database

  Stage runs against Paperboy_Stage, not Paperboy_Dev. That distinction is
  easy to lose: .env is shared with the dev host and sets
  PAPERBOY_DATABASE=Paperboy_Dev, and config/database.yml reads that value in
  every environment, so without an override a staging deploy quietly writes to
  dev. The override is set twice, and both are needed:

  - `Environment=PAPERBOY_DATABASE=Paperboy_Stage` in
    config/systemd/paperboy-stage.service and paperboy-stage-jobs.service,
    after the EnvironmentFile line so it wins — this covers Puma and Solid Queue.
  - `export PAPERBOY_DATABASE=Paperboy_Stage` in bin/deploy-stage — this covers
    db:migrate, acl:sync and the asset tasks the script runs.

  bin/deploy-stage reinstalls both unit files and runs daemon-reload before it
  restarts, the same way bin/deploy does for prod, so a normal deploy picks up
  a change to either one. Where /etc/systemd/system/paperboy-stage*.service are
  symlinks into this repo, git pull has already updated them and the copy is
  skipped — the daemon-reload is still what makes systemd re-read them. To do
  it by hand:

```bash
sudo cp config/systemd/paperboy-stage*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl restart paperboy-stage paperboy-stage-jobs
```

  To confirm which database stage is actually on:

```bash
PAPERBOY_DATABASE=Paperboy_Stage RAILS_ENV=staging bundle exec rails runner \
  'puts ActiveRecord::Base.connection.current_database'
```

  Tail logs while debugging:

```bash
journalctl -u paperboy-stage -f
journalctl -u paperboy-stage-jobs -f
```

## Production Deployment

On Prod Server: bin/deploy

Puma and Solid Queue are managed by systemd, which means:

- They auto-start on server boot
- They auto-restart if they crash
- You can check on them anytime with sudo systemctl status paperboy or sudo
  systemctl status paperboy-jobs
- Logs go to journald: sudo journalctl -u paperboy -f

## Rolling back on Production

Get the tags

```bash
git fetch origin --tags
```

Reset to the previous known-good tag

```bash
git reset --hard prod-20251112-2050  # example tag
```

Rebuild assets + restart app

## Promoting ACLs (dev → stage → prod)

Groups, their permission grants and the org-level grants live in each
Paperboy_* database, not in shared GSABSS, so they have to be carried across
by hand. `db/acl.yml` is that carrier: it is committed, and it describes every
environment at once.

```bash
# On dev, after setting groups and permissions up in ACL > Groups
bin/rails acl:dump MERGE=1        # union dev's ACL into db/acl.yml
git add db/acl.yml && git commit  # read the diff first — org grants are broad

# On stage, then prod, after deploying
bin/rails acl:sync DRY_RUN=1      # print the plan, write nothing
bin/rails acl:sync                # apply it
bin/rails acl:sync PRUNE=1        # also remove grants the file does not list
```

`acl:sync` is additive and safe to re-run: it creates what is missing and
leaves everything else alone. Nothing is matched on an id the local database
owns — groups go by name, forms by class name, org scopes by the shared GSABSS
agency/division/department/unit ids.

A form grant is only applied where the form itself exists, because
`form_templates.id` is allocated per database. Grants for a form the target
does not have are listed as `!` lines and held back rather than pointed at
whatever form happens to hold that id there:

```
! HCA_HR: form/34 — LeaveOfAbsenceForm does not exist in this database; create the form here first
```

So promote the form template first, then re-run `acl:sync` and the held-back
grants land. Two things are deliberately left out of the file: Employee_Groups,
because memberships are meant to differ per environment, and contractors,
because that table carries password digests.

## Form Template Workflow

**This is only intended as a workaround if the UI is broken as this workflow is included in the UI under Admin --> Manage Forms

Paperboy includes a Rails generator for creating new form templates.

1. Generate a new form from template

```bash
bin/rails generate paperboy_form FormName
```

Example:

```bash
bin/rails generate paperboy_form AuthorizationForm
```

Creates:

```text
app/models/authorization_form.rb

app/controllers/authorization_forms_controller.rb

app/views/authorization_forms/new.html.erb

db/migrate/TIMESTAMP_create_authorization_forms.rb

Route: resources :authorization_forms
```

Sidebar link (if the generator inserts it)

2. Run the migration (create the database table)

```bash
bin/rails db:migrate
```

3. Destroy a generated form (undo files + routes)

```bash
bin/rails destroy paperboy_form FormName
```

This removes:

Model, controller, views, routes, Sidebar link, SCSS, Stimulus JS controllers, etc.

Note: Destroying a form cleans up code + routes but leaves tables; drop tables with migrations.

4. Delete the generated table (manually)
Create a migration to drop it:

```bash
bin/rails generate migration DropTestForm
```

Edit the migration:

```ruby
class DropTestForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :test_forms
  end
end
```

Run it:

```bash
bin/rails db:migrate
```

5. ***IF ANY EXIST - Clean up duplicate migrations
If you see errors like wrong number of arguments (given 0, expected 1..2)
or Duplicate migration class CreateAuthorizationForms, you probably have more than one migration file with the same class name.

List duplicate migrations:

```bash
ls db/migrate | grep create_authorization_forms
```

Delete all of them (since the last runs aborted):

```bash
rm db/migrate/*_create_authorization_forms.rb
```

## Sub-Application Workflow

Paperboy is the base app, and the sidebar app switcher can hold others next to
it (Data Runner, Chart of Accounts). Use the app rake task to add another one.

1. Scaffold a new app

```bash
bin/rails "app:new[hello_world]"
```

The name is flexible: hello_world, hello-world, "Hello World" and HelloWorld all
give the same app. Quote the whole thing so the shell keeps the brackets.

Creates:

```text
app/controllers/hello_world/base_controller.rb   (the ACL gate)
app/controllers/hello_world/dashboard_controller.rb
app/views/hello_world/dashboard/index.html.erb
app/views/hello_world/shared/_sidebar.html.erb   (one "Hello World" button)
```

Registers it in:

```text
config/routes.rb                             namespace :hello_world, root dashboard#index
app/helpers/application_helper.rb            app switcher entry + current-app highlight
app/views/shared/_sidebar.html.erb           renders this app's sidebar
app/controllers/acl_controller.rb            the ACL > Applications checkbox
app/assets/stylesheets/layout/_sidebar.scss  sidebar accent theme
```

A display name is derived from the key ("Hello World"). To set your own, pass it
as a second argument — do NOT put quotes around it inside the brackets, rake
takes those literally and they end up in the name:

```bash
bin/rails "app:new[time_sheets,Timesheet Portal]"
```

Options:

```bash
LABEL="Timesheet Portal"  # Display name; same as the second argument above.
THEME=teal                # Accent: teal, blue, cyan, slate, or green.
DRY_RUN=1                 # Print planned changes without writing.
```

Example:

```bash
THEME=blue LABEL="Timesheet Portal" bin/rails "app:new[time_sheets]"
```

2. Grant access (nobody sees it until you do)
Applications are a strict allow-list with no default grants, so a new app is
invisible to everyone except system admins until you grant it:
ACL > pick a group > Permissions > Applications > check the app.

This is enforced in the generated BaseController, not just hidden in the
switcher, so the namespace is not reachable by typing the URL either.

3. Restart and rebuild assets
The sidebar theme is SCSS, so dev needs a rebuild to pick it up:

```bash
bin/rails assets:clobber assets:precompile && sudo systemctl restart paperboy-dev
```

4. Build the app
Add controllers under app/controllers/hello_world/ inheriting from
HelloWorld::BaseController, views under app/views/hello_world/, and more
sidebar buttons in app/views/hello_world/shared/_sidebar.html.erb.

5. List what is registered

```bash
bin/rails app:list
```

6. Destroy an app (undo files + registration + ACL grants)

```bash
bin/rails "app:destroy[hello_world]"
```

Deletes the app's namespaced directories, unregisters it from the five files
above, and revokes its ACL grants — stale grants would otherwise silently
re-grant access if the key is ever reused. It prompts for confirmation; pass
FORCE=1 to skip the prompt (required when not run from a terminal), or
DRY_RUN=1 to preview.

Note: destroy takes the whole namespace, including routes you added inside it.
Paperboy, Data Runner and Chart of Accounts are protected and will not be
removed. Anything outside the app's own directories — say an
app/assets/stylesheets/pages/_hello_world.scss you added by hand and imported
in application.scss — is left alone; clean that up yourself.

Seeding Test Data
Master seeding:

```bash
rails db:seed                     # seed both
ONLY=parking rails db:seed        # seed only Parking Lot
REPLANT=1 rails db:seed           # wipe & reseed both
```

Dev seeding with options:

```bash
rails dev:seed:parking SUBMISSIONS=200 REPLANT=1
rails dev:seed:probation TRANSFERS=80
```

Notes:
Use REPLANT=1 with seeds to reset test data.

## DataRunner Rake Targets

Run DataRunner tasks with Bundler so they use the application's locked gems:

```bash
bundle exec rake 'DataRunner:target[selector]'
```

The selector can be a DSL name, a group name, or `ALL`. The `new_dsl` target
also accepts no selector and then discovers every supported file in
`$DATARUNNER_INBOX`; existing DSL files are skipped. Configure the shared
inbox in `.env`:

```dotenv

DATARUNNER_INBOX=${GSABSS_ROOT}/BUSINESS_SUPPORT/DataRunner/00_Inbox
```

```bash
bundle exec rake DataRunner:new_dsl
bundle exec rake 'DataRunner:new_dsl[widgets]'
bundle exec rake 'DataRunner:refresh[Widgets]'
bundle exec rake 'DataRunner:refresh[ALL]'
```

Available targets:

| Target | Purpose |
| --- | --- |
| `new_dsl` | Create initial DSL files from one or all inbox sources |
| `dsl_stub` | Create a DSL stub from a name or `host.database.schema.name` |
| `sync_dsl` | Create a database DSL and synchronize its SQL metadata and source CSV |
| `download` | Download or validate configured source files |
| `to_csv` | Convert source files into normalized CSV files |
| `to_dsl` | Convert normalized CSV files into DSL mapping scaffolds |
| `to_sql` | Write SQL Server table scaffolds from DSL mappings |
| `dump_sql` | Dump live SQL Server definitions into the schema workspace |
| `from_sql` | Export SQL Server tables into inbox CSV files |
| `table_drop` | Drop configured SQL Server tables |
| `table_create` | Create configured SQL Server tables |
| `use_dsl` | Apply locked DSL mappings to normalized CSV files |
| `use_sql` | Update DSL mappings from reviewed SQL scaffolds |
| `inject` | Load DSL-applied CSV files into SQL Server |
| `setup` | Run `download`, `to_csv`, `to_sql`, and `use_dsl` |
| `oneshot` | Run setup, create tables, and inject the data |
| `refresh` | Run `download`, `to_csv`, `use_dsl`, and `inject` |
| `reset` | Clear staged generated ETL files |
| `reconcile_oms_uploads` | Reconcile OMS upload state from imported data and archives |

List the current targets and their descriptions with:

```bash
bundle exec rake -T DataRunner
```
