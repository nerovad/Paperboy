# frozen_string_literal: true

# Reject reasons (#131): the choices offered when an invoice is rejected.
# A row with no agency group is offered everywhere (AIM Admins keep those);
# the rest belong to one group (its Group Admins keep them). "Other" with a
# typed reason is always offered too.
#
# No database foreign keys and explicit index names: see
# test/lib/aim/schema_conventions_test.rb.
class CreateAimRejectReasons < ActiveRecord::Migration[8.1]
  def change
    create_table 'aim.reject_reasons' do |t|
      t.bigint :agency_group_id
      t.string :label, limit: 200, null: false
      t.integer :position, default: 0, null: false
      t.string :updated_by, limit: 255
      t.timestamps
    end
    add_index 'aim.reject_reasons', %i[agency_group_id position], name: 'index_aim_reject_reasons_on_group_and_position'
  end
end
