# frozen_string_literal: true

# Form access is managed entirely in the ACL screen, so the form builder's
# "Access Level" dropdown — and the column behind it — are gone.
class RemoveVisibilityFromFormTemplates < ActiveRecord::Migration[8.0]
  def change
    remove_column :form_templates, :visibility, :string, default: 'restricted', null: false
  end
end
