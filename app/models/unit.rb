class Unit < GsabssBase
  self.table_name = 'dbo.units'
  self.primary_key = 'unit_id'

  belongs_to :agency, foreign_key: "agency_id", optional: true
  belongs_to :division, foreign_key: "division_id", optional: true
  belongs_to :department, foreign_key: "department_id", optional: true
end
