class DropBikeLockerPermits < ActiveRecord::Migration[8.0]
  def change
    drop_table :bike_locker_permits
  end
end
