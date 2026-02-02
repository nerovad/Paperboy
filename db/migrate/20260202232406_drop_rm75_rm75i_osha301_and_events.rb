class DropRm75Rm75iOsha301AndEvents < ActiveRecord::Migration[8.0]
  def change
    drop_table :rm75_forms
    drop_table :rm75i_forms
    drop_table :osha_301_forms
    drop_table :events
  end
end
