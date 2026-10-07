# frozen_string_literal: true

# The change log behind the parking, badges and keys console: one row per
# authorization added, edited or removed, with the scope before and after.
# authorized_approvers cannot answer this itself — an edit replaces its rows and
# a removal deletes them.
class CreateAuthorizedApproverChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :authorized_approver_changes do |t|
      t.string :action, null: false
      t.string :employee_id, null: false
      t.string :department_id, null: false
      t.string :changed_by, null: false
      t.text :scope_before
      t.text :scope_after
      t.datetime :created_at, null: false
    end

    add_index :authorized_approver_changes, %i[department_id created_at]
  end
end
