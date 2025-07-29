class Agency < ApplicationRecord
  self.table_name = 'dbo.agencies'
  self.primary_key = 'agency_id'
end
