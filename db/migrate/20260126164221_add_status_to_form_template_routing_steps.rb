class AddStatusToFormTemplateRoutingSteps < ActiveRecord::Migration[8.0]
  def change
    add_reference :form_template_routing_steps, :form_template_status, null: true, foreign_key: true
  end
end
