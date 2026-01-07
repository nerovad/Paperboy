class RemoveIncidentManagerAndReportedByFromCriticalInformationReportings < ActiveRecord::Migration[8.0]
  def change
    remove_column :critical_information_reportings, :incident_manager, :string
    remove_column :critical_information_reportings, :reported_by, :string
  end
end
