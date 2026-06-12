class CreateBikeLockerLotsAndLockers < ActiveRecord::Migration[8.0]
  # Bike-locker reference data, Paperboy-owned (Rails migration, runs on deploy).
  #
  # Replaces three legacy repgen tables:
  #   LotNames     -> bike_locker_lots   (the 13 locations)
  #   LockerRanges -> bike_lockers        (the physical locker inventory)
  #   LockerStatus -> merged into bike_lockers (1:1 on the old LockerId)
  #
  # The legacy Assigned/Reserved booleans collapse into a single `status`
  # string; the denormalized EmployeeEmail/Name/Phone columns are dropped in
  # favor of assigned_employee_id (keys to GSABSS Employees by value, not FK,
  # since that table lives in another database — same pattern as
  # employee_union_codes / authorized_approvers). LockType is dropped (it was
  # the constant "User Lock" on every row).
  def change
    create_table :bike_locker_lots do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :bike_locker_lots, :name, unique: true

    create_table :bike_lockers do |t|
      t.references :lot, null: false   # -> bike_locker_lots
      t.integer :locker_number, null: false
      # available | assigned | reserved | out_of_service
      t.string :status, null: false, default: "available"
      t.string :assigned_employee_id   # keys to Employees by value; nil when free
      t.datetime :assigned_at
      t.timestamps
    end

    # A locker number is unique only WITHIN a lot (lots 1/4/6/12 all have a "1").
    add_index :bike_lockers, [:lot_id, :locker_number], unique: true
    # Drives the availability lookup: free lockers for the chosen lot.
    add_index :bike_lockers, [:lot_id, :status]
  end
end
