class CreateCreativeJobRequests < ActiveRecord::Migration[8.0]
  def change
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
