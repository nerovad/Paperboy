class RemoveMediaFromCriticalInformationReportings < ActiveRecord::Migration[8.0]
  def change
    remove_column :critical_information_reportings, :media, :string
  end
end
