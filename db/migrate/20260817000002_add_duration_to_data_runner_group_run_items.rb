# frozen_string_literal: true

class AddDurationToDataRunnerGroupRunItems < ActiveRecord::Migration[8.0]
  def change
    add_column :data_runner_group_run_items, :duration_ms, :integer
  end
end
