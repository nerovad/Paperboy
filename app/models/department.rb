class Department < ApplicationRecord
  self.table_name = 'dbo.departments'
  self.primary_key = 'department_id'
end
