class CreateFormSystem < ActiveRecord::Migration[8.0]
  def change
    # Form Templates
    create_table :form_templates do |t|
      t.string :name, null: false
      t.string :class_name, null: false
      t.string :access_level, default: "public", null: false
      t.integer :acl_group_id
      t.integer :page_count, default: 2, null: false
      t.text :page_headers
      t.integer :created_by
      t.string :submission_type, default: "database"
      t.string :approval_routing_to
      t.integer :approval_employee_id
      t.string :powerbi_workspace_id
      t.string :powerbi_report_id
      t.boolean :has_dashboard, default: false
      t.text :inbox_buttons
      t.string :status_transition_mode, default: "automatic"
      t.text :tags
      t.string :org_scope_type
      t.string :org_scope_id
      t.timestamps
    end
    add_index :form_templates, :class_name, unique: true

    # Form Fields
    create_table :form_fields do |t|
      t.references :form_template, null: false, foreign_key: true
      t.string :field_name, null: false
      t.string :field_type, null: false
      t.string :label
      t.integer :page_number, null: false
      t.integer :position
      t.text :options
      t.boolean :required, default: false
      t.string :restricted_to_type, default: "none"
      t.integer :restricted_to_employee_id
      t.integer :restricted_to_group_id
      t.integer :conditional_field_id
      t.text :conditional_values
      t.timestamps
    end
    add_index :form_fields, [:form_template_id, :page_number]
    add_index :form_fields, [:form_template_id, :position]
    add_index :form_fields, :restricted_to_type
    add_index :form_fields, :conditional_field_id

    # Form Template Statuses
    create_table :form_template_statuses do |t|
      t.references :form_template, null: false, foreign_key: true
      t.string :name, null: false
      t.string :key, null: false
      t.string :category, null: false
      t.integer :position, default: 0
      t.boolean :is_initial, default: false
      t.boolean :is_end, default: false
      t.timestamps
    end
    add_index :form_template_statuses, [:form_template_id, :key], unique: true
    add_index :form_template_statuses, [:form_template_id, :position]

    # Form Template Routing Steps
    create_table :form_template_routing_steps do |t|
      t.references :form_template, null: false, foreign_key: true
      t.integer :step_number, null: false
      t.string :routing_type, null: false
      t.integer :employee_id
      t.references :form_template_status, foreign_key: true
      t.timestamps
    end
    add_index :form_template_routing_steps, [:form_template_id, :step_number], unique: true, name: "idx_routing_steps_template_step"
  end
end
