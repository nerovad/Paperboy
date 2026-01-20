class CreateFormTemplateRoutingSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :form_template_routing_steps do |t|
      t.references :form_template, null: false, foreign_key: true
      t.integer :step_number, null: false
      t.string :routing_type, null: false
      t.integer :employee_id
      t.timestamps
    end

    add_index :form_template_routing_steps, [:form_template_id, :step_number], unique: true, name: 'idx_routing_steps_template_step'
  end
end
