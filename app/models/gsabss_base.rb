# app/models/gsabss_base.rb
class GsabssBase < ApplicationRecord
  self.abstract_class = true
  connects_to database: { writing: :gsabss }
end

class Agency < GsabssBase
  self.table_name = 'dbo.TC60._Agencies'
end

class Division < GsabssBase
  self.table_name = 'dbo.TC60_Divisions'
end

class Department < GsabssBase
  self.table_name = 'dbo.TC60_Departments'
end

class Unit < GsabssBase
  self.table_name = 'dbo.TC60_Units'
end

