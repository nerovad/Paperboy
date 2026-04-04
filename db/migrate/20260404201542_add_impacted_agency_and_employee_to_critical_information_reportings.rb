class AddImpactedAgencyAndEmployeeToCriticalInformationReportings < ActiveRecord::Migration[8.0]
  def change
    add_column :critical_information_reportings, :impacted_agency, :string
    add_column :critical_information_reportings, :impacted_employee, :string
  end
end
