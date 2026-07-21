# frozen_string_literal: true

# One audited change to one column of one Records-grid row. Written inside the
# same transaction as the edit itself, so a saved batch and its audit trail
# either both land or neither does.
#
# The row is referenced polymorphically rather than by association because the
# tables a grid can edit are open-ended (see RegistryTable). `table_slug` is
# stored alongside so an edit stays attributable even if a model is later
# renamed or a form-backed table is unflagged.
class RecordEdit < ApplicationRecord
  # Written once and never touched again — there is no updated_at.
  self.record_timestamps = false

  belongs_to :record, polymorphic: true, optional: true

  validates :record_type, :record_id, :table_slug, :column_name, presence: true

  scope :newest_first, -> { order(created_at: :desc) }
  scope :for_row, ->(row) { where(record_type: row.class.name, record_id: row.id) }

  # Capture one column change on `row`. Values are stringified because a single
  # column here holds whatever type the edited column was.
  def self.capture(row:, table_slug:, column_name:, old_value:, new_value:, actor: nil)
    create!(
      record_type: row.class.name,
      record_id: row.id,
      table_slug: table_slug,
      column_name: column_name.to_s,
      old_value: old_value&.to_s,
      new_value: new_value&.to_s,
      changed_by_id: actor&.dig(:id),
      changed_by_name: actor&.dig(:name),
      created_at: Time.current
    )
  end
end
