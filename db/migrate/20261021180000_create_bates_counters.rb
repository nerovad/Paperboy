# frozen_string_literal: true

# Bates stamping (#230): named counters, each with the next number to give,
# zero-padded to its digits, and the stamp's layout (any prefix is text in a
# stamp row), and a log of every run -- who stamped what, and the range of
# numbers it took, padded as it was stamped. Runs are append-only; a
# counter's next number only moves forward with a run or by hand.
#
# A second run, or a run after a crash, creates only what is missing.
class CreateBatesCounters < ActiveRecord::Migration[8.1]
  def up
    unless table_exists?(:bates_counters)
      create_table :bates_counters do |t|
        t.string :name, limit: 100, null: false
        t.integer :digits, null: false, default: 6
        t.bigint :next_number, null: false, default: 1
        t.text :areas
        t.integer :page_shrink
        t.string :page_position, limit: 10
        t.string :created_by, limit: 255, null: false
        t.string :updated_by, limit: 255
        t.timestamps
      end
    end
    add_index :bates_counters, :name, unique: true, name: 'index_bates_counters_on_name', if_not_exists: true
    return if table_exists?(:bates_runs)

    create_table :bates_runs do |t|
      t.bigint :bates_counter_id, null: false
      t.integer :digits, null: false
      t.bigint :first_number, null: false
      t.bigint :last_number, null: false
      t.integer :page_count, null: false
      t.text :file_names
      t.string :created_by, limit: 255, null: false
      t.datetime :created_at, null: false
    end
    add_index :bates_runs, %i[bates_counter_id created_at], name: 'index_bates_runs_on_counter_and_created_at'
  end

  def down
    drop_table :bates_runs if table_exists?(:bates_runs)
    drop_table :bates_counters if table_exists?(:bates_counters)
  end
end
