class AddInboxButtonsToFormTemplateRoutingSteps < ActiveRecord::Migration[8.0]
  def up
    add_column :form_template_routing_steps, :inbox_buttons, :text

    # Backfill each routing step with its parent template's inbox_buttons so
    # existing forms keep behavior. JSON-encoded to match the model accessor.
    say_with_time 'Backfilling inbox_buttons from form_templates' do
      execute(<<~SQL)
        UPDATE rs
        SET rs.inbox_buttons = ft.inbox_buttons
        FROM form_template_routing_steps rs
        INNER JOIN form_templates ft ON ft.id = rs.form_template_id
        WHERE ft.inbox_buttons IS NOT NULL
      SQL
    end
  end

  def down
    remove_column :form_template_routing_steps, :inbox_buttons
  end
end
