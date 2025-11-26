class AddFieldsToCriticalInformationReportings < ActiveRecord::Migration[8.0]
  def change
    add_column :critical_information_reportings, :incident_type, :string
    add_column :critical_information_reportings, :incident_details, :text
    add_column :critical_information_reportings, :cause, :text
    add_column :critical_information_reportings, :staff_involved, :string
    add_column :critical_information_reportings, :incident_manager, :string
    add_column :critical_information_reportings, :reported_by, :string
    add_column :critical_information_reportings, :impact_started, :datetime
    add_column :critical_information_reportings, :location, :string
    add_column :critical_information_reportings, :status, :string
    add_column :critical_information_reportings, :actual_completion_date, :datetime
    add_column :critical_information_reportings, :urgency, :string
    add_column :critical_information_reportings, :impact, :string
    add_column :critical_information_reportings, :impacted_customers, :string
    add_column :critical_information_reportings, :next_steps, :text
    add_column :critical_information_reportings, :media, :string
  end
end
