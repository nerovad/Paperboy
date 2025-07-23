class Employee < ApplicationRecord
  self.table_name = "[GSABSS].[dbo].[Employees]"
  self.primary_key = "EmployeeID"
end
