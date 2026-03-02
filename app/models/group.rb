# app/models/group.rb
class Group < ApplicationRecord
  self.table_name = 'Groups'
  self.primary_key = 'GroupID'

  # Column aliases: MSSQL PascalCase → Rails snake_case
  alias_attribute :group_name, :Group_Name
  alias_attribute :description, :Description
  alias_attribute :created_at, :Created_At

  has_many :employee_groups, foreign_key: 'GroupID', dependent: :destroy
  has_many :employees, through: :employee_groups
  has_many :group_permissions, foreign_key: 'GroupID', dependent: :destroy
end
