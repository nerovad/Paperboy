# frozen_string_literal: true

# A routing step may now send a submission to several parties at once.
#
# form_template_step_routes is the configuration: the routes a 'multiple' step
# fans out to. submission_step_tasks is what happens: one row per route for
# each submission that lands on such a step, checked off on its own. A task
# copies its route's target and label rather than pointing at it, because the
# form builder destroys and rebuilds a template's steps on every routing edit
# and a submission in flight has to keep its checklist.
#
# Existing steps get the two rule columns at their defaults and no routes, so
# nothing about a single-route step changes.
class CreateStepRoutesAndSubmissionStepTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :form_template_routing_steps, :completion_rule, :string, null: false, default: 'all'
    add_column :form_template_routing_steps, :deny_rule, :string, null: false, default: 'form'

    create_table :form_template_step_routes do |t|
      t.bigint :form_template_routing_step_id, null: false
      t.integer :position, null: false, default: 0
      t.string :routing_type, null: false
      t.integer :employee_id
      t.integer :group_id
      t.string :org_filter_level
      t.string :authorization_service_type
      t.string :label
      t.timestamps

      t.index :form_template_routing_step_id
    end

    create_table :submission_step_tasks do |t|
      t.string :submission_type, null: false
      t.bigint :submission_id, null: false
      t.integer :step_number, null: false
      t.integer :position, null: false, default: 0
      t.string :label, null: false
      t.string :routing_type, null: false
      t.integer :employee_id
      t.integer :group_id
      t.string :org_filter_level
      t.string :authorization_service_type
      t.string :assignee_id
      t.string :state, null: false, default: 'pending'
      t.string :acted_by_id
      t.string :acted_by_name
      t.datetime :acted_at
      t.text :notes
      t.timestamps

      t.index %i[submission_type submission_id step_number], name: 'index_submission_step_tasks_on_submission'
      t.index %i[submission_type state assignee_id], name: 'index_submission_step_tasks_on_open_assignee'
    end
  end
end
