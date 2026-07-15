# Paperboy (Ventura County Forms App)

**Ruby version:**  

```bash
ruby 3.4.4 (2025-05-14 revision a38531fd3f) +PRISM [x86_64-linux]

**Rails version:**  
Rails 8.0.2

Paperboy is a Ruby on Rails 8.x application for managing internal forms (e.g., Parking Lot Submissions, Probation Transfer Requests, Safety Reporting, etc.) with a modernized workflow.  
It integrates with Microsoft SQL Server and uses Sidekiq for background jobs.

For the product story / sales pitch, see [docs/PITCH.md](docs/PITCH.md).

---
## Dev deployment systemd - Only PUMA restart
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

## Stage Deployment
  Restart Puma (just Puma):
  sudo systemctl restart paperboy-stage

  Restart both (Puma + Sidekiq):
  sudo systemctl restart paperboy-stage paperboy-stage-sidekiq

  Full deploy (git pull → bundle → assets:clobber → assets:precompile → restart both):
  bin/deploy-stage              # deploys master
  bin/deploy-stage some-branch  # deploys a different branch

  It mirrors bin/deploy-dev exactly, except it runs RAILS_ENV=staging, bundle install --without development test, and restarts
  the paperboy-stage* units. You'll get prompted for your sudo password at the two systemctl restart calls near the end.

  Tail logs while debugging:
  journalctl -u paperboy-stage -f
  journalctl -u paperboy-stage-sidekiq -f
## Pushing to Github
Push code from dev server to github
git status
git add .
git commit -m ""
git push

Rollback Strategy

Before each deploy, snapshot what’s currently in prod with a tag so you can roll back easily.

10.1. Tag the current prod version (from dev or any machine with the repo)

cd ~/gitea/Paperboy

# Example: prod-20251112-2050
TAG_NAME="prod-$(date +%Y%m%d-%H%M)"

git tag -a "$TAG_NAME" -m "Deploy to prod at $TAG_NAME"
git push origin --tags

## Pulling Code to Production Server
  On Dev — write code, commit, push to Gitea
  On Prod — run bin/deploy and it handles everything:
  1. git pull the latest code
  2. bundle install for any new gems
  3. assets:clobber + assets:precompile for a clean asset build
  4. Restarts Puma and Sidekiq via systemd

  Puma and Sidekiq are managed by systemd, which means:
  - They auto-start on server boot
  - They auto-restart if they crash
  - You can check on them anytime with sudo systemctl status paperboy or sudo systemctl status paperboy-sidekiq
  - Logs go to journald: sudo journalctl -u paperboy -f

## Rolling back on Production
Get the tags
git fetch origin --tags

Reset to the previous known-good tag
git reset --hard prod-20251112-2050  # example tag

Rebuild assets + restart app

## Running the App

Frontend (Rails server):

Dev:
bin/rails s -p 3001

Direct localhost development runs over HTTP:

APP_HOST=http://localhost:3001
PAPERBOY_ASSUME_SSL=false

When running development behind nginx with HTTPS termination
(https://dev-gsa-forms), opt in to Rails SSL assumptions:

APP_HOST=https://dev-gsa-forms
PAPERBOY_ASSUME_SSL=true

Employee Login uses OmniAuth 2 and must submit with POST plus a Rails
authenticity token. If login raises ActionController::InvalidAuthenticityToken
on localhost, confirm the browser origin and APP_HOST are both HTTP and
PAPERBOY_ASSUME_SSL is false.

Production:
RAILS_ENV=production bin/rails s -b 127.0.0.1 -p 3001

Backend (background jobs):

Dev:
bundle exec sidekiq

Production:
bundle exec sidekiq -e production

##Form Template Workflow

Paperboy includes a Rails generator for creating new form templates.

1. Generate a new form from template
bin/rails generate paperboy_form FormName
Example:
bin/rails generate paperboy_form AuthorizationForm
Creates:

app/models/authorization_form.rb

app/controllers/authorization_forms_controller.rb

app/views/authorization_forms/new.html.erb

db/migrate/TIMESTAMP_create_authorization_forms.rb

Route: resources :authorization_forms

Sidebar link (if the generator inserts it)

2. Run the migration (create the database table)
bin/rails db:migrate

3. Destroy a generated form (undo files + routes)
bin/rails destroy paperboy_form FormName

This removes:

Model, controller, views, routes, Sidebar link, SCSS, Stimulus JS controllers, etc.

Note: Destroying a form cleans up code + routes but leaves tables; drop tables with migrations.

4. Delete the generated table (manually)
Create a migration to drop it:

bin/rails generate migration DropTestForm
Edit the migration:

class DropTestForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :test_forms
  end
end

Run it:

bin/rails db:migrate

5. ***IF ANY EXIST - Clean up duplicate migrations
If you see errors like wrong number of arguments (given 0, expected 1..2)
or Duplicate migration class CreateAuthorizationForms, you probably have more than one migration file with the same class name.

List duplicate migrations:

ls db/migrate | grep create_authorization_forms
Delete all of them (since the last runs aborted):

rm db/migrate/*_create_authorization_forms.rb


##Sub-Application Workflow

Paperboy is the base app, and the sidebar app switcher can hold others next to
it (Data Runner, Chart of Accounts). Use the app rake task to add another one.

1. Scaffold a new app
bin/rails "app:new[hello_world]"

The name is flexible: hello_world, hello-world, "Hello World" and HelloWorld all
give the same app. Quote the whole thing so the shell keeps the brackets.

Creates:

app/controllers/hello_world/base_controller.rb   (the ACL gate)
app/controllers/hello_world/dashboard_controller.rb
app/views/hello_world/dashboard/index.html.erb
app/views/hello_world/shared/_sidebar.html.erb   (one "Hello World" button)

Registers it in:

config/routes.rb                             namespace :hello_world, root dashboard#index
app/helpers/application_helper.rb            app switcher entry + current-app highlight
app/views/shared/_sidebar.html.erb           renders this app's sidebar
app/controllers/acl_controller.rb            the ACL > Applications checkbox
app/assets/stylesheets/layout/_sidebar.scss  sidebar accent theme

A display name is derived from the key ("Hello World"). To set your own, pass it
as a second argument — do NOT put quotes around it inside the brackets, rake
takes those literally and they end up in the name:

bin/rails "app:new[time_sheets,Timesheet Portal]"

Options:
LABEL="Timesheet Portal"  display name, same as the second argument above
THEME=teal                sidebar accent: teal (default), blue, cyan, slate, green
DRY_RUN=1                 print what it would do and write nothing

Example:
THEME=blue LABEL="Timesheet Portal" bin/rails "app:new[time_sheets]"

2. Grant access (nobody sees it until you do)
Applications are a strict allow-list with no default grants, so a new app is
invisible to everyone except system admins until you grant it:
ACL > pick a group > Permissions > Applications > check the app.

This is enforced in the generated BaseController, not just hidden in the
switcher, so the namespace is not reachable by typing the URL either.

3. Restart and rebuild assets
The sidebar theme is SCSS, so dev needs a rebuild to pick it up:
bin/rails assets:clobber assets:precompile && sudo systemctl restart paperboy-dev

4. Build the app
Add controllers under app/controllers/hello_world/ inheriting from
HelloWorld::BaseController, views under app/views/hello_world/, and more
sidebar buttons in app/views/hello_world/shared/_sidebar.html.erb.

5. List what is registered
bin/rails app:list

6. Destroy an app (undo files + registration + ACL grants)
bin/rails "app:destroy[hello_world]"

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

rails db:seed                     # seed both
ONLY=parking rails db:seed        # seed only Parking Lot
REPLANT=1 rails db:seed           # wipe & reseed both
Dev seeding with options:

rails dev:seed:parking SUBMISSIONS=200 REPLANT=1
rails dev:seed:probation TRANSFERS=80

Notes:
Use REPLANT=1 with seeds to reset test data.

##MSSQL gsasql16 Command for Linux Terminal viewing. With alias.
prettysql "SELECT TOP 50 * FROM GSABSS.dbo.Employees"

#Claude Code Git Reversion Best Practices
Best practices:

Start each Claude Code session with a clean commit:

git add .
   git commit -m "Pre-Claude: baseline before [task description]"
   claude

Review Claude's changes before accepting them - you can use Plan Mode 
(--permission-mode plan or Shift+Tab to cycle to it) to see what Claude 
wants to do before it makes changes

If you mistakenly accept unwanted changes:

# See what changed
   git status
   git diff
   
   # Revert specific files
   git checkout -- path/to/file
   
   # Or revert everything to last commit
   git reset --hard HEAD
   
   # Or if you already committed, revert the commit
   git revert HEAD

Use branches for risky tasks:

git checkout -b claude-experiment
   claude
   # Review changes, then decide to merge or discard

Best Practice for Paperboy Development

# Start feature work
git checkout -b feature/badge-request-acls
git commit -m "Baseline before Claude session"

# Work with Claude, commit frequently
claude
# ... Claude makes changes ...
git add .
git commit -m "Claude: Initial ACL implementation"
# ... more Claude work ...
git commit -m "Claude: Fix Employee lookup"

# Review and clean up
git log --oneline -5
git rebase -i HEAD~4  # Squash Claude's commits into logical units

# Test thoroughly
bundle exec rspec
rails s  # Manual testing

# NOW push to remote for PR/review
git push origin feature/badge-request-acls
