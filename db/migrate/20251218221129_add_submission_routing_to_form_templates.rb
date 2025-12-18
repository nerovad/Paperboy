class AddSubmissionRoutingToFormTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :form_templates, :submission_type, :string, default: 'database'
    add_column :form_templates, :approval_routing_to, :string
    add_column :form_templates, :approval_employee_id, :integer
  end
end
