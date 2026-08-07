# frozen_string_literal: true

# Namespace for the Digital Asset Management domain models.
#
# The controllers live under DigitalAssetManagement (the app key the sidebar
# and ACL know it by); the models live under the shorter Dam because they are
# referenced constantly and dam_ is the table prefix.
module Dam
  def self.table_name_prefix
    'dam_'
  end
end
