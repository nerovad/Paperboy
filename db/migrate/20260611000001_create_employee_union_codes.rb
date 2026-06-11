class CreateEmployeeUnionCodes < ActiveRecord::Migration[8.0]
  # Union / bargaining-unit codes (e.g. "MB3") are Paperboy-owned data. They
  # cannot live on the GSABSS Employees table, which is read-only reference data
  # refreshed from the source system and does not carry this column. employee_id
  # is a string to match the rest of the app (see authorized_approvers); it keys
  # to Employees by value, not by FK, since that table lives in another database.
  def change
    create_table :employee_union_codes do |t|
      t.string :employee_id, null: false
      t.string :union_code, null: false
      t.timestamps
    end

    add_index :employee_union_codes, :employee_id, unique: true
  end
end
