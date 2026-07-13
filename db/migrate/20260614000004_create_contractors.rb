# frozen_string_literal: true

class CreateContractors < ActiveRecord::Migration[8.0]
  # Contractors are non-Active-Directory users that a system admin provisions by
  # hand. They cannot live on the GSABSS Employees table (read-only reference
  # data refreshed from the source system), so they are a Paperboy-owned table.
  #
  # The PK is reseeded to start at 1,000,000,000 so contractor ids never collide
  # with GSABSS Employee ids (which are far below that). That non-collision is
  # what lets submissions store the submitter as a single integer `employee_id`
  # and lets the workflow engine resolve it with `Employee.find_by(...) ||
  # Contractor.find_by(...)` without an extra discriminator column. It also lets
  # contractors reuse the existing Employee_Groups membership/ACL pipeline as-is.
  CONTRACTOR_ID_SEED = 1_000_000_000

  def up
    create_table :contractors do |t|
      # Identity / submitter interface (mirrors the Employee columns the
      # workflow + prefill code reads).
      t.string :first_name, null: false
      t.string :last_name,  null: false
      t.string :email,      null: false
      t.string :work_phone

      # Business unit + supervisor, assigned per-contractor at creation. These
      # are org *codes* (strings), exactly like Employee.agency/department/unit.
      # supervisor_id points at a real Employee who does the approving.
      t.string  :agency
      t.string  :department
      t.string  :unit
      t.integer :supervisor_id

      # Authentication. No password is set at creation — the welcome email sends
      # a one-time set-password link (a signed `generates_token_for` token, same
      # mechanism as password reset), so a usable credential is never emailed or
      # stored. The token is signed/stateless, so no token columns are needed:
      # it auto-invalidates once password_digest changes.
      t.string   :password_digest

      # Lifecycle. Contractors expire one year out by default (editable) and can
      # be deactivated when an engagement ends.
      t.boolean  :active, null: false, default: true
      t.datetime :expires_at

      t.timestamps
    end

    add_index :contractors, :email, unique: true

    # Reseed identity so the first inserted contractor gets CONTRACTOR_ID_SEED.
    # On a freshly created (never-inserted) table, SQL Server uses the reseed
    # value AS-IS for the first row, so we reseed to SEED itself.
    execute "DBCC CHECKIDENT('contractors', RESEED, #{CONTRACTOR_ID_SEED})"
  end

  def down
    drop_table :contractors
  end
end
