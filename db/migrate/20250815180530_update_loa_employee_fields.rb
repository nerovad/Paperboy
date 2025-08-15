# db/migrate/20250815180530_update_loa_employee_fields.rb
class UpdateLoaEmployeeFields < ActiveRecord::Migration[7.1]
  def up
    add_column :loa_forms, :employee_name, :string unless column_exists?(:loa_forms, :employee_name)
    add_column :loa_forms, :work_email,    :string unless column_exists?(:loa_forms, :work_email)

    # --- Backfill employee_name/work_email ---
    if column_exists?(:loa_forms, :first_name) || column_exists?(:loa_forms, :middle_name) || column_exists?(:loa_forms, :last_name)
      # Case 1: legacy name columns exist on loa_forms -> build locally
      execute <<~SQL
        UPDATE loa_forms
        SET employee_name = LTRIM(RTRIM(
            COALESCE(NULLIF(first_name, ''), '')
            + CASE WHEN NULLIF(last_name,  '') IS NOT NULL THEN N' ' + last_name  ELSE N'' END
        ))
        WHERE (employee_name IS NULL OR employee_name = '')
          AND (first_name IS NOT NULL OR middle_name IS NOT NULL OR last_name IS NOT NULL);
      SQL
    else
      # Case 2: no legacy columns -> join to Employees by employee_id (SQL Server-safe)
      execute <<~SQL
        UPDATE lf
        SET
          employee_name = COALESCE(NULLIF(lf.employee_name, ''), LTRIM(RTRIM(
            COALESCE(NULLIF(e.First_Name,  ''), '')
            + CASE WHEN NULLIF(e.Last_Name,   '') IS NOT NULL THEN N' ' + e.Last_Name   ELSE N'' END
          ))),
          work_email    = COALESCE(NULLIF(lf.work_email, ''), e.EE_Email)
        FROM loa_forms lf
        LEFT JOIN Employees e ON e.EmployeeID = lf.employee_id
        WHERE (lf.employee_name IS NULL OR lf.employee_name = '')
           OR (lf.work_email  IS NULL OR lf.work_email  = '');
      SQL
    end

    # Drop any legacy columns ONLY if they exist (safe no-ops otherwise)
    %i[first_name middle_name last_name street_address city state zip_code
       home_phone cell_phone work_phone personal_email].each do |col|
      remove_column :loa_forms, col if column_exists?(:loa_forms, col)
    end
  end

  def down
    # Recreate legacy columns empty so the migration is reversible
    %i[first_name middle_name last_name street_address city state zip_code
       home_phone cell_phone work_phone personal_email].each do |col|
      add_column :loa_forms, col, :string unless column_exists?(:loa_forms, col)
    end

    remove_column :loa_forms, :employee_name if column_exists?(:loa_forms, :employee_name)
    # keep work_email unless you explicitly want to drop it:
    # remove_column :loa_forms, :work_email if column_exists?(:loa_forms, :work_email)
  end
end
