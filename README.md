# Paperboy (Ventura County Forms App)

**Ruby version:**  

```bash
ruby 3.4.4 (2025-05-14 revision a38531fd3f) +PRISM [x86_64-linux]

**Rails version:**  
Rails 8.0.2

Paperboy is a Ruby on Rails 8.x application for managing internal forms (e.g., Parking Lot Submissions, Probation Transfer Requests, RM-75, etc.) with a modernized workflow.  
It integrates with Microsoft SQL Server and uses Sidekiq for background jobs.

---

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
