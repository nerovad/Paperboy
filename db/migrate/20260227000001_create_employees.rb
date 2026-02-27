class CreateEmployees < ActiveRecord::Migration[8.0]
  def change
    create_table :employees, id: false do |t|
      t.integer :employee_id, null: false
      t.string :first_name, limit: 50
      t.string :last_name, limit: 50
      t.string :email, limit: 50
      t.string :work_phone, limit: 50
      t.integer :supervisor_id
      t.string :supervisor_first_name, limit: 50
      t.string :supervisor_last_name, limit: 50
      t.string :job_title, limit: 50
      t.string :job_code, limit: 50
      t.integer :job_class
      t.string :pay_status, limit: 50
      t.string :union_code, limit: 50
      t.string :employee_type, limit: 50
      t.string :agency, limit: 50
      t.string :department, limit: 50
      t.string :unit, limit: 50
      t.string :position, limit: 50
    end

    add_index :employees, :employee_id, unique: true
    execute "ALTER TABLE employees ADD PRIMARY KEY (employee_id)"
  end
end
