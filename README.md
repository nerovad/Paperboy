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
with a modernized workflow.  It integrates with Microsoft SQL Server and uses
Sidekiq for background jobs.

For the product story / sales pitch, see [docs/PITCH.md](docs/PITCH.md).

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

System packages (Ubuntu; see [Redis-compatible queue
service](#redis-compatible-queue-service) below for the Arch/Valkey
equivalent):

```bash
sudo apt install build-essential libyaml-dev libffi-dev \
                 freetds-dev freetds-bin redis-server
sudo systemctl enable --now redis-server
redis-cli ping     # expect PONG
```

`freetds-dev` backs the `tiny_tds` gem. Then:

```bash
bundle install
```

### The .env file

`.env` is gitignored, so it does not arrive with a fresh clone — copy it
from another machine. `config/database.yml` uses `ENV.fetch` with no
defaults, so Rails will not boot without it. At minimum:

```bash
GSABSS_HOST=  GSABSS_PORT=  GSABSS_USERNAME=  GSABSS_PASSWORD=
GSABSS_DATABASE=GSABSS
PAPERBOY_DATABASE=Paperboy_Dev
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=
REDIS_URL=redis://localhost:6379/0
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
bin/dev-local            # Puma on :3001 + Sidekiq, one terminal
bin/dev-local 3005       # different port
bin/dev-local --cron     # also run the scheduled jobs
bin/dev-local --no-jobs  # Puma only
```

It preflights `.env`, the port and Redis, prefixes Sidekiq output with
`[sidekiq]`, and shuts both processes down together on Ctrl-C. If one
dies the other is torn down with it.

`bin/dev` still works if you only want Puma with no preflight.

### Two things to know

**There is no local database.** `development` points at `Paperboy_Dev` on
the shared SQL Server, so this machine needs network access to it, and
anything you write is visible to everyone else on dev. Avoid `bin/setup`
— it runs `db:prepare`, which would migrate the shared database.

**Scheduled jobs are off by default.** `bin/dev-local` sets
`PAPERBOY_DISABLE_CRON=true`, because the cron schedule loads at Sidekiq
boot whether or not `-C` is passed. Left on, a workstation runs
`OshaReportableDeadlineJob` hourly against `Paperboy_Dev`, and that job
writes `reportable_breach_notified_at` as its dedupe stamp — so it would
race the dev server and consume notices the server should have sent. Pass
`--cron` only when you are deliberately testing a scheduled job. Servers
never set the variable and keep their schedule.

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

## Redis-compatible queue service

Sidekiq requires a Redis-compatible server on `127.0.0.1:6379`. On
Arch/Omarchy, install and start Valkey (the supported Redis replacement):

```bash
sudo pacman -S valkey
sudo systemctl enable --now valkey
valkey-cli ping
```

The health check must return `PONG`. The default application setting is
`REDIS_URL=redis://localhost:6379/0`; Valkey supports this protocol and URL.

To run Sidekiq directly during development:

```bash
bundle exec sidekiq -C config/sidekiq.yml
```

For managed deployments, ensure `valkey.service` is running before the
`paperboy-*-sidekiq` service starts.

## Dev deployment systemd - Only PUMA restart

```bash
sudo systemctl restart paperboy-dev

# Deploying with git pull, bundle install, pre-compile, puma restart, Sidekiq restart
bin/deploy-dev

# Check Logs
sudo journalctl -u paperboy-dev -f
sudo journalctl -u paperboy-dev-sidekiq -f

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

  Restart both (Puma + Sidekiq):

```bash
sudo systemctl restart paperboy-stage paperboy-stage-sidekiq
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
    config/systemd/paperboy-stage.service and paperboy-stage-sidekiq.service,
    after the EnvironmentFile line so it wins — this covers Puma and Sidekiq.
  - `export PAPERBOY_DATABASE=Paperboy_Stage` in bin/deploy-stage — this covers
    db:migrate, acl:sync and the asset tasks the script runs.

  After pulling a change to either unit file, reinstall them on the stage host:

```bash
sudo cp config/systemd/paperboy-stage*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl restart paperboy-stage paperboy-stage-sidekiq
```

  To confirm which database stage is actually on:

```bash
PAPERBOY_DATABASE=Paperboy_Stage RAILS_ENV=staging bundle exec rails runner \
  'puts ActiveRecord::Base.connection.current_database'
```

  Tail logs while debugging:

```bash
journalctl -u paperboy-stage -f
journalctl -u paperboy-stage-sidekiq -f
```

## Production Deployment

On Prod Server: bin/deploy

Puma and Sidekiq are managed by systemd, which means:

- They auto-start on server boot
- They auto-restart if they crash
- You can check on them anytime with sudo systemctl status paperboy or sudo
  systemctl status paperboy-sidekiq
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
