class CreateProbationTransferRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :probation_transfer_requests do |t|
      t.string :employee_id
      t.string :name
      t.string :email
      t.string :phone
      t.string :agency
      t.string :division
      t.string :department
      t.string :unit
      t.string :work_location
      t.date :current_assignment_date
      t.text :desired_transfer_destination
      t.integer :status

      t.timestamps
    end
  end
end
