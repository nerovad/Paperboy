class DropOldRm75AndRm75iSubmissions < ActiveRecord::Migration[8.0]
  def change
    drop_table :rm75_submissions, if_exists: true
    drop_table :rm75i_submissions, if_exists: true
  end
end
