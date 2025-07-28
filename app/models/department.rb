class Department < ApplicationRecord
  self.table_name = 'dbo.departments'
  self.primary_key = 'department_id'

  belongs_to :agency, foreign_key: 'agency_id'
  belongs_to :division, foreign_key: 'division_id'
end
