class AddGroupIdToFormTemplateRoutingSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :form_template_routing_steps, :group_id, :integer
  end
end
