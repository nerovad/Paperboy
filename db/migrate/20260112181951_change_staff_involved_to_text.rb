class ChangeStaffInvolvedToText < ActiveRecord::Migration[8.0]
  def change
    change_column :critical_information_reportings, :staff_involved, :text
  end
end
