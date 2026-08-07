# frozen_string_literal: true

# One outbound share of an asset or a collection — what "My Shares" lists.
#
# Rows are never deleted when a share ends; revoking stamps `revoked_at`. The
# screen is a *history*, and "who did I send the unreleased campaign to last
# spring" is the question it exists to answer.
class CreateDamShares < ActiveRecord::Migration[8.0]
  def change
    create_table :dam_shares do |t|
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.string :subject_label

      t.string :token, null: false
      # view | download — whether the recipient gets the master or a preview.
      t.string :permission, null: false, default: 'view'

      t.string :shared_by_id
      t.string :shared_by_name
      t.text :recipients, comment: 'Newline-separated email addresses'
      t.text :message

      t.datetime :expires_at
      t.datetime :revoked_at
      t.datetime :last_accessed_at
      t.integer :access_count, null: false, default: 0

      t.timestamps
    end

    add_index :dam_shares, :token, unique: true
    add_index :dam_shares, :shared_by_id
    add_index :dam_shares, %i[subject_type subject_id]
    add_index :dam_shares, :created_at
  end
end
