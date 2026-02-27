class CreateFormSubmissions < ActiveRecord::Migration[8.0]
  def change
    # Parking Lot Submissions
    create_table :parking_lot_submissions do |t|
      t.string :name, limit: 200
      t.string :phone, limit: 25
      t.string :employee_id, limit: 20
      t.string :email, limit: 200
      t.string :agency, limit: 100
      t.string :division, limit: 100
      t.string :department, limit: 100
      t.string :unit, limit: 100
      t.integer :status
      t.string :supervisor_id, limit: 20
      t.string :approved_by, limit: 20
      t.datetime :approved_at
      t.string :denied_by, limit: 20
      t.datetime :denied_at
      t.text :denial_reason
      t.string :supervisor_email, limit: 200
      t.string :delegated_approver_id
      t.string :delegated_approver_email
      t.string :delegated_approved_by
      t.datetime :delegated_approved_at
      t.timestamps
    end

    # Parking Lot Vehicles
    create_table :parking_lot_vehicles do |t|
      t.references :parking_lot_submission, null: false, foreign_key: true
      t.string :make, limit: 50
      t.string :model, limit: 50
      t.string :color, limit: 20
      t.integer :year
      t.string :license_plate, limit: 15
      t.string :parking_lot, limit: 100
      t.string :other_parking_lot, limit: 100
      t.timestamps
    end

    # Probation Transfer Requests
    create_table :probation_transfer_requests do |t|
      t.string :employee_id, limit: 20
      t.string :name, limit: 200
      t.string :email, limit: 200
      t.string :phone, limit: 25
      t.string :agency, limit: 100
      t.string :division, limit: 100
      t.string :department, limit: 100
      t.string :unit, limit: 100
      t.string :work_location, limit: 100
      t.date :current_assignment_date
      t.text :desired_transfer_destination
      t.integer :status, default: 0, null: false
      t.string :other_transfer_destination, limit: 200
      t.string :approved_by, limit: 20
      t.datetime :approved_at
      t.string :denied_by, limit: 20
      t.datetime :denied_at
      t.text :denial_reason
      t.string :supervisor_email, limit: 200
      t.string :supervisor_id, limit: 20
      t.datetime :expires_at
      t.datetime :canceled_at
      t.string :canceled_reason, limit: 100
      t.bigint :superseded_by_id
      t.string :approved_destination
      t.timestamps
    end
    add_index :probation_transfer_requests, :status
    add_index :probation_transfer_requests, :expires_at
    add_index :probation_transfer_requests, :canceled_at
    add_index :probation_transfer_requests, :approved_destination
    add_index :probation_transfer_requests, :superseded_by_id

    # Critical Information Reportings
    create_table :critical_information_reportings do |t|
      t.string :employee_id
      t.string :name
      t.string :phone
      t.string :email
      t.string :agency
      t.string :division
      t.string :department
      t.string :unit
      t.string :incident_type
      t.text :incident_details
      t.text :cause
      t.text :staff_involved
      t.datetime :impact_started
      t.string :location
      t.datetime :actual_completion_date
      t.string :urgency
      t.string :impact
      t.string :impacted_customers
      t.text :next_steps
      t.integer :status, default: 0
      t.string :assigned_manager_id
      t.timestamps
    end

    # Creative Job Requests
    create_table :creative_job_requests do |t|
      t.string :job_id
      t.string :job_title
      t.string :job_type
      t.string :job_agency
      t.string :job_division
      t.string :job_department
      t.string :job_unit
      t.string :asset_type
      t.string :employee_name
      t.string :location
      t.date :date
      t.text :description
      t.timestamps
    end
  end
end
