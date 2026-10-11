# frozen_string_literal: true

class AddCurrentStepToDataRunnerGroupRunItems < ActiveRecord::Migration[8.1]
  def change
    add_column :data_runner_group_run_items, :current_step, :string
  end
end
