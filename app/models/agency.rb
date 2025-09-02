# app/models/agency.rb
class Agency < ApplicationRecord
  self.table_name  = 'dbo.agencies'     # ✅ your current table
  self.primary_key = 'agency_id'
end

# app/models/division.rb
class Division < ApplicationRecord
  self.table_name  = 'dbo.divisions'    # <- adjust if yours is different
  self.primary_key = 'division_id'
  # typically has: agency_id, name, long_name, short_name
end

# app/models/department.rb
class Department < ApplicationRecord
  self.table_name  = 'dbo.departments'  # <- adjust if needed
  self.primary_key = 'department_id'
  # typically has: division_id, long_name, ...
end

# app/models/unit.rb
class Unit < ApplicationRecord
  self.table_name  = 'dbo.units'        # <- adjust if needed
  self.primary_key = 'unit_id'
  # typically has: department_id, long_name, short_name
end
