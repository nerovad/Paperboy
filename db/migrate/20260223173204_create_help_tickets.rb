class CreateHelpTickets < ActiveRecord::Migration[8.0]
  def change
    create_table :help_tickets do |t|
      t.string :subject, null: false
      t.text :description, null: false
      t.string :employee_id, null: false
      t.string :employee_name
      t.string :employee_email
      t.integer :status, default: 0, null: false
      t.timestamps
    end

    add_index :help_tickets, :employee_id
  end
end
