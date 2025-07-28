class Agency < ApplicationRecord
  self.table_name = 'dbo.agencies'
  self.primary_key = 'agency_id'

  has_many :divisions, foreign_key: 'agency_id'
  has_many :departments, foreign_key: 'agency_id'
  has_many :sub_units, foreign_key: 'agency_id'
end
