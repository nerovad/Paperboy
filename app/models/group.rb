# app/models/group.rb
class Group < ApplicationRecord
  self.table_name = 'Groups'
  self.primary_key = 'GroupID'
  
  has_many :employee_groups, foreign_key: 'GroupID'
  has_many :employees, through: :employee_groups
  has_many :group_permissions, foreign_key: 'GroupID'
end
