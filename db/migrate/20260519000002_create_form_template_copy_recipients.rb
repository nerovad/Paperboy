class CreateFormTemplateCopyRecipients < ActiveRecord::Migration[8.0]
  def change
    create_table :form_template_copy_recipients do |t|
      t.bigint :form_template_id, null: false
      t.string :recipient_type, null: false
      t.integer :employee_id
      t.integer :group_id
      t.string :trigger_event, null: false, default: 'approval'
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :form_template_copy_recipients, :form_template_id
    add_foreign_key :form_template_copy_recipients, :form_templates
  end
end
