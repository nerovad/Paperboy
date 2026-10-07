# frozen_string_literal: true

# authorization_managers now says who manages which departments in the parking,
# badges and keys console. A removal is kept as a row rather than deleted, so
# the table itself answers who appointed or removed a manager, and when.
class AddAssignmentAuditToAuthorizationManagers < ActiveRecord::Migration[8.1]
  def change
    add_column :authorization_managers, :assigned_by, :string
    add_column :authorization_managers, :removed_by, :string
    add_column :authorization_managers, :removed_at, :datetime
  end
end
