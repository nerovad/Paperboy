class CreateCarpoolForms < ActiveRecord::Migration[7.1]
  def change
    create_table :carpool_forms do |t|
      # Baseline fields for your two-page template
      t.string :employee_id
      t.string :name
      t.string :phone
      t.string :email

      t.string :agency
      t.string :division
      t.string :department
      t.string :unit

      t.integer :status, default: 0

      t.timestamps
    end
  end
end
