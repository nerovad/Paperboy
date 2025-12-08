class CreateFormFields < ActiveRecord::Migration[7.1]
  def change
    create_table :form_fields do |t|
      t.references :form_template, null: false, foreign_key: true
      t.string :field_name, null: false
      t.string :field_type, null: false
      t.string :label
      t.integer :page_number, null: false
      t.integer :position
      t.json :options
      t.boolean :required, default: false
      
      t.timestamps
    end

    add_index :form_fields, [:form_template_id, :page_number]
    add_index :form_fields, [:form_template_id, :position]
  end
end
