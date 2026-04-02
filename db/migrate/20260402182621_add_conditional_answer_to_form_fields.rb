class AddConditionalAnswerToFormFields < ActiveRecord::Migration[8.0]
  def change
    add_column :form_fields, :conditional_answer_field_id, :integer
    add_column :form_fields, :conditional_answer_mappings, :text
    add_index :form_fields, :conditional_answer_field_id
  end
end
