class AddRestrictedToOrgFilterLevelToFormFields < ActiveRecord::Migration[8.0]
  def change
    add_column :form_fields, :restricted_to_org_filter_level, :string
  end
end
