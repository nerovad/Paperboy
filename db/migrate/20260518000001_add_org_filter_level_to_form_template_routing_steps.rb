# frozen_string_literal: true

class AddOrgFilterLevelToFormTemplateRoutingSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :form_template_routing_steps, :org_filter_level, :string
  end
end
