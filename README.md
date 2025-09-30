# Paperboy (Ventura County Forms App)


**Ruby version:**  
```bash
ruby 3.4.4 (2025-05-14 revision a38531fd3f) +PRISM [x86_64-linux]

**Rails version:**  
Rails 8.0.2

Paperboy is a Ruby on Rails 8.x application for managing internal forms (e.g., Parking Lot Submissions, Probation Transfer Requests, RM-75, etc.) with a modernized workflow.  
It integrates with Microsoft SQL Server and uses Sidekiq for background jobs.

---

## Running the App

Frontend (Rails server):

```bash
bin/rails s -p 3001
Backend (background jobs):

bash
Copy code
bundle exec sidekiq
Form Template Workflow
Paperboy includes a Rails generator for creating new form templates.

1. Generate a new form from template
bash
Copy code
bin/rails generate paperboy_form FormName
Example:

bash
Copy code
bin/rails generate paperboy_form AuthorizationForm
Creates:

app/models/authorization_form.rb

app/controllers/authorization_forms_controller.rb

app/views/authorization_forms/new.html.erb

db/migrate/TIMESTAMP_create_authorization_forms.rb

Route: resources :authorization_forms

Sidebar link (if the generator inserts it)

2. Run the migration (create the database table)
bash
Copy code
bin/rails db:migrate
3. Clean up duplicate migrations
If you see errors like wrong number of arguments (given 0, expected 1..2)
or Duplicate migration class CreateAuthorizationForms, you probably have more than one migration file with the same class name.

List duplicate migrations:

bash
Copy code
ls db/migrate | grep create_authorization_forms
Delete all of them (since the last runs aborted):

bash
Copy code
rm db/migrate/*_create_authorization_forms.rb
Then re-generate the form:

bash
Copy code
bin/rails generate paperboy_form AuthorizationForm
4. Destroy a generated form (undo files + routes)
bash
Copy code
bin/rails destroy paperboy_form FormName
Example:

bash
Copy code
bin/rails destroy paperboy_form AuthorizationForm
This removes:

Model, controller, views, routes

Sidebar link, SCSS, Stimulus JS controllers, etc.

❗ Note: This does not remove the DB table automatically (see below).

5. Roll back a migration (undo the DB table)
Roll back the last migration:

bash
Copy code
bin/rails db:rollback STEP=1
Roll back multiple (e.g., last 3):

bash
Copy code
bin/rails db:rollback STEP=3
Drop & recreate the entire DB (nuclear option):

bash
Copy code
bin/rails db:drop db:create db:migrate
6. List all tables in the current database
bash
Copy code
bin/rails dbconsole
Inside the DB console:

SQLite:

sql
Copy code
.tables;
PostgreSQL:

sql
Copy code
\dt
SQL Server:

sql
Copy code
SELECT name FROM sys.tables;
(exit with \q)

7. Delete a specific table (manually)
Create a migration to drop it:

bash
Copy code
bin/rails generate migration DropAuthorizationForms
Edit the migration:

ruby
Copy code
class DropAuthorizationForms < ActiveRecord::Migration[7.1]
  def change
    drop_table :authorization_forms
  end
end
Run it:

bash
Copy code
bin/rails db:migrate
Seeding Test Data
Master seeding:

bash
Copy code
rails db:seed                     # seed both
ONLY=parking rails db:seed        # seed only Parking Lot
REPLANT=1 rails db:seed           # wipe & reseed both
Dev seeding with options:

bash
Copy code
rails dev:seed:parking SUBMISSIONS=200 REPLANT=1
rails dev:seed:probation TRANSFERS=80
Notes
Use bin/rails generate paperboy_form for new forms instead of manual setup.

Always run db:migrate after generating or editing migrations.

Destroying a form cleans up code + routes but leaves tables; drop tables with migrations.

Use REPLANT=1 with seeds to reset test data.

Sidekiq must be running for background jobs and email notifications.

Duplicate migrations cause strange errors → clean them up before running db:migrate.
