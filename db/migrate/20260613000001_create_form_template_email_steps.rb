class CreateFormTemplateEmailSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :form_template_email_steps do |t|
      t.bigint :form_template_id, null: false
      # When the email fires: submit | approved | denied
      t.string :trigger_event, null: false, default: 'submit'
      # For approved/denied: the routing step whose action triggers this email.
      # NULL means the form's final approved/denied outcome.
      t.integer :routing_step_number
      # Who receives it: submitter | employee | group | custom_email | form_field
      t.string :recipient_type, null: false
      t.integer :employee_id
      t.integer :group_id
      t.string :custom_email
      t.string :recipient_field_name
      t.string :subject
      t.text :body
      t.boolean :attach_pdf, null: false, default: false
      t.boolean :attach_media, null: false, default: false
      t.integer :position, default: 0
      t.timestamps
    end

    add_index :form_template_email_steps, :form_template_id
    add_foreign_key :form_template_email_steps, :form_templates
  end
end
