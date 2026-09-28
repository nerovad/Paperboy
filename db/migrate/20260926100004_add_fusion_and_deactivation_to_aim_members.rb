# frozen_string_literal: true

# Two things about a person on the AIM list (item a.2):
# - what Fusion said about them, kept from the import so their profile can
#   suggest a role (a suggestion, never a grant);
# - whether they are inactive: someone who left keeps their record and history
#   but drops out of the picker and the queues, and can be brought back.
class AddFusionAndDeactivationToAimMembers < ActiveRecord::Migration[8.1]
  def change
    add_column 'aim.members', :fusion_team, :string, limit: 100
    add_column 'aim.members', :fusion_roles, :string, limit: 255
    add_column 'aim.members', :deactivated_at, :datetime
    add_column 'aim.members', :deactivated_by, :string, limit: 255
    add_column 'aim.members', :deactivation_reason, :string, limit: 500
  end
end
