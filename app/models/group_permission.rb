# app/models/group_permission.rb
class GroupPermission < ApplicationRecord
  self.table_name = 'Group_Permissions'

  # Column aliases: MSSQL PascalCase → Rails snake_case
  alias_attribute :group_id, :GroupID
  alias_attribute :permission_type, :Permission_Type
  alias_attribute :permission_key, :Permission_Key

  belongs_to :group, foreign_key: 'GroupID'
end
