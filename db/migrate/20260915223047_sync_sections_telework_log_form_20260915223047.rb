# frozen_string_literal: true

class SyncSectionsTeleworkLogForm20260915223047 < ActiveRecord::Migration[7.1]
  def change
    add_column :telework_log_form_work_performeds, :hours, :integer
  end
end
