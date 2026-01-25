class CreateFormTemplateStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :form_template_statuses do |t|
      t.references :form_template, null: false, foreign_key: true
      t.string :name, null: false
      t.string :key, null: false
      t.string :category, null: false
      t.integer :position, default: 0
      t.boolean :is_initial, default: false
      t.boolean :is_terminal, default: false

      t.timestamps
    end

    add_index :form_template_statuses, [:form_template_id, :key], unique: true
    add_index :form_template_statuses, [:form_template_id, :position]
  end
end
