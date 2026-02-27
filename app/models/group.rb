# app/models/group.rb
class Group < ApplicationRecord
  has_many :employee_groups, dependent: :destroy
  has_many :employees, through: :employee_groups
  has_many :group_permissions, dependent: :destroy
end
