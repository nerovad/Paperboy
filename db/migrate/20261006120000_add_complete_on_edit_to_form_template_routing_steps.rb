# frozen_string_literal: true

# A routing step whose approver finishes it by filling in the form rather than
# by pressing Approve (Safety Reporting: the safety officer completes the
# investigation pages, and saving them is the sign-off).
class AddCompleteOnEditToFormTemplateRoutingSteps < ActiveRecord::Migration[8.1]
  def change
    add_column :form_template_routing_steps, :complete_on_edit, :boolean, default: false, null: false
  end
end
