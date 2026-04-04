class AddBuildingToCriticalInformationReportings < ActiveRecord::Migration[8.0]
  def change
    add_column :critical_information_reportings, :building, :string
    add_column :critical_information_reportings, :other_building, :string
  end
end
