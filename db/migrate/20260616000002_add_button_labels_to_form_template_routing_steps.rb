# frozen_string_literal: true

class AddButtonLabelsToFormTemplateRoutingSteps < ActiveRecord::Migration[8.0]
  # Optional per-step overrides for the inbox Approve/Deny button text. The
  # action is unchanged (approve still advances the workflow, deny still
  # rejects) — only the label shown to the approver differs. Lets a step read
  # "Permit Printed" / "Permit Picked Up" while behaving like a normal approval.
  # Blank falls back to the default "Approve"/"Deny".
  def change
    add_column :form_template_routing_steps, :approve_button_label, :string
    add_column :form_template_routing_steps, :deny_button_label, :string
  end
end
