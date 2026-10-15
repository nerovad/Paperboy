# frozen_string_literal: true

# Email alert settings (#131): per agency group (budget_unit blank), with a
# budget unit's own overriding its group's. One row per kind of alert. Nothing
# is sent unless AIM_EMAIL_ALERTS=on (Aim::Alerts).
#
# No database foreign keys and explicit index names: see
# test/lib/aim/schema_conventions_test.rb.
class CreateAimAlertSettings < ActiveRecord::Migration[8.1]
  def change
    create_table 'aim.alert_settings' do |t|
      t.bigint :agency_group_id, null: false
      t.string :budget_unit, limit: 10
      t.string :kind, limit: 40, null: false
      t.boolean :enabled, default: true, null: false
      t.integer :days
      t.string :updated_by, limit: 255
      t.timestamps
    end
    add_index 'aim.alert_settings', %i[agency_group_id budget_unit kind], unique: true,
                                                                          name: 'index_aim_alert_settings_on_group_unit_kind'
  end
end
