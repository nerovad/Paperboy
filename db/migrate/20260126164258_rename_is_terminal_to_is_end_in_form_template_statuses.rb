class RenameIsTerminalToIsEndInFormTemplateStatuses < ActiveRecord::Migration[8.0]
  def change
    rename_column :form_template_statuses, :is_terminal, :is_end
  end
end
