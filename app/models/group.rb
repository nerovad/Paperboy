# frozen_string_literal: true

# app/models/group.rb
class Group < ApplicationRecord
  self.table_name = 'Groups'
  self.primary_key = 'GroupID'

  # The group whose members administer everything, ACL included.
  PRIVILEGED_NAME = 'system_admins'

  # Column aliases: MSSQL PascalCase → Rails snake_case
  alias_attribute :group_name, :Group_Name
  alias_attribute :description, :Description
  alias_attribute :created_at, :Created_At

  has_many :employee_groups, foreign_key: 'GroupID', dependent: :destroy
  # disable_joins: Employees lives in the GSABSS DB while Employee_Groups
  # lives in the Paperboy DB — Rails cannot JOIN across connections.
  has_many :employees, through: :employee_groups, disable_joins: true
  has_many :group_permissions, foreign_key: 'GroupID', dependent: :destroy

  # Employee ids (integers, each once) of the members of the groups with these
  # names. Group names compare as the database collates them (SQL Server:
  # case-insensitive). Groups live in Paperboy and Employees in GSABSS, so
  # this is the id list to look employees up by, not a join.
  def self.employee_ids_named(*names)
    EmployeeGroup.member_ids(where(Group_Name: names.flatten).select(:GroupID))
  end
end
