# frozen_string_literal: true

class AddSubmissionAuditToOsha300aEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :osha_300a_entries, :submitted_payload, :text
    add_column :osha_300a_entries, :submission_response, :text
    add_column :osha_300a_entries, :submitted_by_id, :string
  end
end
