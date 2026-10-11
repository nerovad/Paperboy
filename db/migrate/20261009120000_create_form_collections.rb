# frozen_string_literal: true

# Form Library collections: a named group of forms for one audience, with who
# made it and when. Membership is one row per form, keyed the way the form ACL
# keys a form — a template's id, or a legacy form's permission key — so a
# collection can hold either kind.
class CreateFormCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :form_collections do |t|
      t.string :name, null: false
      t.text :description
      t.string :created_by_id
      t.string :created_by_name
      t.timestamps
    end

    add_index :form_collections, :name

    create_table :form_collection_forms do |t|
      t.references :form_collection, null: false, foreign_key: true
      t.string :form_key, null: false
      t.string :added_by_id
      t.datetime :created_at, null: false
    end

    add_index :form_collection_forms, %i[form_collection_id form_key], unique: true
  end
end
