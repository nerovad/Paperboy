class Division < ApplicationRecord
  self.table_name = 'dbo.divisions'
  self.primary_key = 'division_id'

  belongs_to :agency, foreign_key: 'agency_id'
  has_many :departments, foreign_key: 'division_id'
end
