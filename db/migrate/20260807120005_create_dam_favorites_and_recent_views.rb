# frozen_string_literal: true

# The two tables behind the Dashboard: what you starred, and what you last
# looked at.
#
# Both are polymorphic because the Dashboard shows favourite/recent *assets*
# and *collections* side by side, and every future DAM noun (a saved search, a
# workflow) will want the same treatment.
class CreateDamFavoritesAndRecentViews < ActiveRecord::Migration[8.0]
  def change
    create_table :dam_favorites do |t|
      t.string :employee_id, null: false
      t.string :favoritable_type, null: false
      t.bigint :favoritable_id, null: false
      t.datetime :created_at, null: false
    end

    add_index :dam_favorites, %i[employee_id favoritable_type favoritable_id],
              unique: true, name: 'index_dam_favorites_on_employee_and_subject'

    create_table :dam_recent_views do |t|
      t.string :employee_id, null: false
      t.string :viewable_type, null: false
      t.bigint :viewable_id, null: false
      # Upserted on each view rather than appended, so "recent" stays a short
      # list of distinct things instead of a visit log that has to be
      # de-duplicated on every dashboard render.
      t.datetime :viewed_at, null: false
      t.integer :view_count, null: false, default: 1
    end

    add_index :dam_recent_views, %i[employee_id viewable_type viewable_id],
              unique: true, name: 'index_dam_recent_views_on_employee_and_subject'
    add_index :dam_recent_views, %i[employee_id viewed_at]
  end
end
