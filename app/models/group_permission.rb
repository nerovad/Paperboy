# app/models/group_permission.rb
class GroupPermission < ApplicationRecord
  self.table_name = 'Group_Permissions'

  belongs_to :group, foreign_key: 'GroupID'
end
