# frozen_string_literal: true

# AIM v2: the row is the invoice. What the workers and the review screens used
# to keep in queue folders and sidecar files -- what to do next, why a person
# is needed, the split manifest, the raw extraction, the reviewer's notes --
# becomes columns. See the AIM Plan wiki page, "AIM v2 -- The Row-First Rebuild":
# http://10.135.204.125:3000/BSS/Paperboy/wiki/AIM-Plan
#
# Additive: every existing column stays. Existing rows' states are mapped from
# the v1 queue names to the v2 states below.
class AddV2ColumnsToAimInvoices < ActiveRecord::Migration[8.1]
  STATE_MAP = {
    'received' => %w[ai_queue pending_vision reprocess],
    'needs_split' => %w[batch_split ready_to_split],
    'needs_review' => %w[vendor_review ready_to_learn low_confidence_review action_needed
                         manual_processing error_queue sql_failed],
    'ready_for_approval' => %w[user_approval],
    'approved' => %w[sql_queue],
    'exported' => %w[archived],
    'deleted' => %w[ready_to_delete]
  }.freeze

  def up
    change_table 'aim.invoices', bulk: true do |t|
      t.string :command, limit: 20
      t.integer :attempt, null: false, default: 0
      t.string :lease_owner, limit: 100
      t.datetime :lease_until
      t.string :review_reason, limit: 40
      t.text :review_note
      t.text :notes
      t.bigint :parent_id
      t.string :source_filename, limit: 260
      t.string :source_path, limit: 1000
      t.string :content_hash, limit: 64
      t.integer :page_count
      t.decimal :subtotal, precision: 15, scale: 2
      t.decimal :sales_tax, precision: 15, scale: 2
      t.text :extracted
      t.text :manifest
      t.boolean :split_check, null: false, default: true
      t.boolean :high_confidence
      t.datetime :exported_at
    end

    add_index 'aim.invoices', :parent_id, name: 'index_aim_invoices_on_parent_id'
    add_index 'aim.invoices', :content_hash, name: 'index_aim_invoices_on_content_hash'
    add_index 'aim.invoices', %i[command lease_until], name: 'index_aim_invoices_on_command_and_lease_until'

    STATE_MAP.each do |to, froms|
      froms.each do |from|
        execute "UPDATE aim.invoices SET state = #{quote(to)} WHERE state = #{quote(from)}"
      end
    end
  end

  def down
    remove_index 'aim.invoices', name: 'index_aim_invoices_on_command_and_lease_until'
    remove_index 'aim.invoices', name: 'index_aim_invoices_on_content_hash'
    remove_index 'aim.invoices', name: 'index_aim_invoices_on_parent_id'

    change_table 'aim.invoices', bulk: true do |t|
      t.remove :command, :attempt, :lease_owner, :lease_until, :review_reason, :review_note, :notes,
               :parent_id, :source_filename, :source_path, :content_hash, :page_count, :subtotal,
               :sales_tax, :extracted, :manifest, :split_check, :high_confidence, :exported_at
    end
  end
end
