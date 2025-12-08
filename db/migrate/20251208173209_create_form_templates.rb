# db/migrate/YYYYMMDDHHMMSS_create_form_templates.rb
class CreateFormTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :form_templates do |t|
      t.string :name, null: false
      t.string :class_name, null: false  # e.g., "AuthorizationForm"
      t.string :access_level, null: false, default: 'public'  # 'public' or 'restricted'
      t.integer :acl_group_id  # References GSABSS.dbo.Groups
      t.integer :page_count, null: false, default: 2
      t.json :page_headers  # Array of page header names
      t.integer :created_by  # employee_id of creator
      
      t.timestamps
    end

    add_index :form_templates, :class_name, unique: true
  end
end
