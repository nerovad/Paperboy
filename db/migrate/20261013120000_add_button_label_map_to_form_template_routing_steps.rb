# frozen_string_literal: true

class AddButtonLabelMapToFormTemplateRoutingSteps < ActiveRecord::Migration[8.0]
  # A step could rename two inbox buttons, each through its own column. Any
  # button can be renamed now, so the labels live in one JSON map keyed by
  # button type ({"approve": "Permit Printed"}). A label still changes the
  # text alone, never what the button does.
  #
  # approve_button_label and deny_button_label are copied across and then left
  # in place, unread: the Data Runner replication of this table names them.
  class Step < ActiveRecord::Base
    self.table_name = 'form_template_routing_steps'
  end

  def up
    add_column :form_template_routing_steps, :button_labels, :text
    Step.reset_column_information

    Step.where.not(approve_button_label: nil).or(Step.where.not(deny_button_label: nil)).find_each do |step|
      labels = { 'approve' => step.approve_button_label, 'deny' => step.deny_button_label }.compact_blank
      step.update_columns(button_labels: labels.to_json) if labels.any?
    end
  end

  def down
    remove_column :form_template_routing_steps, :button_labels
  end
end
