class CreatePcardInventories < ActiveRecord::Migration[7.1]
  def change
    create_table :pcard_inventories do |t|
      t.string :last_name
      t.string :first_name
      t.string :agency
      t.string :division
      t.string :mail_stop
      t.string :address
      t.string :city
      t.string :state
      t.string :zip
      t.string :phone
      t.decimal :single_purchase_limit, precision: 10, scale: 2
      t.decimal :monthly_limit, precision: 10, scale: 2
      t.string :card_number
      t.date :issued_date
      t.date :expiration_date
      t.date :canceled_date
      t.string :agent
      t.string :company
      t.string :division_number
      t.string :approver_name
      t.string :org_number
      t.string :dept_head_agency
      t.string :billing_contact

      # Link back to the approved p-card request form (optional)
      t.references :pcard_request_form, foreign_key: true

      t.timestamps
    end

    add_index :pcard_inventories, :last_name
    add_index :pcard_inventories, :card_number
  end
end
