class AddLockerSelectionToBikeLockerForms < ActiveRecord::Migration[8.0]
  # Wire the bike locker request to the new lookup tables. locker_id is the
  # chosen physical locker (FK to bike_lockers, keyed on its id because
  # locker_number is unique only within a lot). locker_location / locker_number
  # are point-in-time snapshots of the request for display + PDF, derived from
  # the chosen locker on save — these field names already existed in the
  # form-builder view but never had backing columns, so editing a submission
  # raised NoMethodError until now.
  def change
    add_column :bike_locker_forms, :locker_id, :bigint
    add_column :bike_locker_forms, :locker_location, :string
    add_column :bike_locker_forms, :locker_number, :string
    add_column :bike_locker_forms, :number_of_bikes, :integer

    add_index :bike_locker_forms, :locker_id
  end
end
