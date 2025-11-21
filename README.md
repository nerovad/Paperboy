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
On the prod server:

git pull

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

3. Clean up duplicate migrations
If you see errors like wrong number of arguments (given 0, expected 1..2)
or Duplicate migration class CreateAuthorizationForms, you probably have more than one migration file with the same class name.

List duplicate migrations:

ls db/migrate | grep create_authorization_forms
Delete all of them (since the last runs aborted):

rm db/migrate/*_create_authorization_forms.rb

4. Destroy a generated form (undo files + routes)
bin/rails destroy paperboy_form FormName

This removes:

Model, controller, views, routes

Sidebar link, SCSS, Stimulus JS controllers, etc.

❗ Note: This does not remove the DB table automatically (see below).

5. Roll back a migration (undo the DB table)
Roll back the last migration:

bin/rails db:rollback STEP=1
Roll back multiple (e.g., last 3):

bin/rails db:rollback STEP=3
Drop & recreate the entire DB (nuclear option):

bin/rails db:drop db:create db:migrate

6. List all tables in the current database
bin/rails dbconsole
Inside the DB console:

sql
SELECT name FROM sys.tables;
(exit with \q)

7. Delete a specific table (manually)
Create a migration to drop it:

bin/rails generate migration DropAuthorizationForms
Edit the migration:

ruby
class DropAuthorizationForms < ActiveRecord::Migration[7.1]
  def change
    drop_table :authorization_forms
  end
end
Run it:

bin/rails db:migrate
Seeding Test Data
Master seeding:

rails db:seed                     # seed both
ONLY=parking rails db:seed        # seed only Parking Lot
REPLANT=1 rails db:seed           # wipe & reseed both
Dev seeding with options:

rails dev:seed:parking SUBMISSIONS=200 REPLANT=1
rails dev:seed:probation TRANSFERS=80
Notes
Use bin/rails generate paperboy_form for new forms instead of manual setup.

Always run db:migrate after generating or editing migrations.

Destroying a form cleans up code + routes but leaves tables; drop tables with migrations.

Use REPLANT=1 with seeds to reset test data.

Sidekiq must be running for background jobs and email notifications.

Duplicate migrations cause strange errors → clean them up before running db:migrate.
