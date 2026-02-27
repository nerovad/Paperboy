# app/models/employee.rb
class Employee < ApplicationRecord
  self.primary_key = 'employee_id'

  has_many :employee_groups, foreign_key: :employee_id
  has_many :groups, through: :employee_groups

  # Helper method to check group membership
  def in_group?(name)
    groups.exists?(group_name: name)
  end

  # Helper to check multiple groups (user needs ANY of them)
  def in_any_group?(*group_names)
    groups.where(group_name: group_names).exists?
  end
end
