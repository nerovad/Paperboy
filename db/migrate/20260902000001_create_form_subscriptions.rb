# frozen_string_literal: true

class CreateFormSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :form_subscriptions do |t|
      t.string :form_type, null: false
      t.string :grantee_type, null: false
      t.string :employee_id
      t.integer :group_id
      t.boolean :notify_created, null: false, default: false
      t.boolean :notify_edited, null: false, default: false
      t.boolean :notify_status_changed, null: false, default: false
      t.string :delivery_mode, null: false, default: 'immediate'
      t.timestamps
    end

    add_index :form_subscriptions, %i[form_type grantee_type employee_id group_id],
              unique: true, name: 'index_form_subscriptions_on_target'
    add_index :form_subscriptions, :delivery_mode
  end
end
