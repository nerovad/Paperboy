# frozen_string_literal: true

# A group subscription mails every member; an opt-out lets one member stop that
# mail without leaving the group. `required` is the admin's way of saying a
# subscription is not optional, and it overrides any opt-out.
class AddOptOutsToFormSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :form_subscriptions, :required, :boolean, null: false, default: false

    create_table :form_subscription_opt_outs do |t|
      t.references :form_subscription, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :employee_id, null: false
      t.timestamps
    end

    add_index :form_subscription_opt_outs, %i[form_subscription_id employee_id],
              unique: true, name: 'index_form_subscription_opt_outs_on_member'
    add_index :form_subscription_opt_outs, :employee_id
  end
end
