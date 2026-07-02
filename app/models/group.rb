# app/models/group.rb
class Group < ApplicationRecord
  self.table_name = "Groups"
  self.primary_key = "GroupID"

  # Column aliases: MSSQL PascalCase → Rails snake_case
  alias_attribute :group_name, :Group_Name
  alias_attribute :description, :Description
  alias_attribute :created_at, :Created_At

  has_many :employee_groups, foreign_key: "GroupID", dependent: :destroy
  # disable_joins: Employees lives in the GSABSS DB while Employee_Groups
  # lives in the Paperboy DB — Rails cannot JOIN across connections.
  has_many :employees, through: :employee_groups, disable_joins: true
  has_many :group_permissions, foreign_key: "GroupID", dependent: :destroy
end
