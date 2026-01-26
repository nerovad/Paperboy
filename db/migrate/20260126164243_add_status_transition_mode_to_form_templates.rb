class AddStatusTransitionModeToFormTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :form_templates, :status_transition_mode, :string, default: 'automatic'
  end
end
