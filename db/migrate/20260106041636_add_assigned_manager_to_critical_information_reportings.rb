class AddAssignedManagerToCriticalInformationReportings < ActiveRecord::Migration[8.0]
  def change
    add_column :critical_information_reportings, :assigned_manager_id, :string
  end
end
