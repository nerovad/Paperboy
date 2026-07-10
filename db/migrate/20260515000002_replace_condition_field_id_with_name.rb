# frozen_string_literal: true

class ReplaceConditionFieldIdWithName < ActiveRecord::Migration[8.0]
  def change
    remove_column :form_template_routing_steps, :condition_field_id, :integer
    add_column :form_template_routing_steps, :condition_field_name, :string
  end
end
