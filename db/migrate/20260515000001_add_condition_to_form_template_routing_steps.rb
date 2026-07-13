# frozen_string_literal: true

class AddConditionToFormTemplateRoutingSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :form_template_routing_steps, :condition_field_id, :integer
    add_column :form_template_routing_steps, :condition_operator, :string
    add_column :form_template_routing_steps, :condition_value, :string
  end
end
