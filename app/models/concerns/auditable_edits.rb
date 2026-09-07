# frozen_string_literal: true

# app/models/concerns/auditable_edits.rb
#
# Field-level audit trail for one record: who changed which column, from what
# to what, and when. Every form the inbox/submissions Edit button can reach
# includes this — directly, or through TrackableStatus, which includes it and
# layers subscription mail on top via #after_edits_captured.
#
# Split out of TrackableStatus so auditing no longer depends on a form also
# having a status workflow: CreativeJobRequest has no status column at all and
# is still audited.
module AuditableEdits
  extend ActiveSupport::Concern

  # Columns an edit log should never carry. `status` is left out because
  # StatusChange already records transitions in full, with labels rather than
  # raw values; approver_id and the timestamps are routing mechanics rather
  # than anything a person edited.
  IGNORED_COLUMNS = %w[id created_at updated_at status approver_id].freeze

  included do
    has_many :record_edits, as: :record, class_name: 'RecordEdit',
                            dependent: :destroy, inverse_of: :record
    after_update :audit_field_edits
  end

  # This record's whole edit history, newest first. Reads the Records grid's
  # audit table, so an edit made inline in the grid and one made through the
  # form both surface here.
  def edit_timeline
    RecordEdit.for_row(self).newest_first
  end

  private

  # Record what actually changed on this update, then hand the rows to whatever
  # else wants to know. Capturing and announcing are one callback because a
  # notifier needs to name the very rows this save wrote -- capturing them
  # separately would leave it guessing which edits belonged to the save.
  def audit_field_edits
    edit_ids = capture_field_edits
    after_edits_captured(edit_ids) if edit_ids.any?
  end

  # What happens once an edit is on the record. A no-op here; TrackableStatus
  # overrides it to mail the people following the form.
  def after_edits_captured(_edit_ids); end

  # Write one RecordEdit per column that actually moved, and return their ids.
  # Values come from saved_changes, so this reflects what the database took,
  # not what was assigned. Shares the Records grid's audit table: an edit is an
  # edit whether it arrived through the grid or the form, and RecordEdit#for_row
  # then returns a record's whole history from one place.
  def capture_field_edits
    changes = saved_changes.except(*IGNORED_COLUMNS)
    return [] if changes.empty?

    actor = { id: Current.user&.dig('employee_id')&.to_s, name: current_user_display_name }

    changes.filter_map do |column, (before, after)|
      next if before.to_s == after.to_s

      RecordEdit.capture(row: self, table_slug: edit_audit_table_slug, column_name: column,
                         old_value: before, new_value: after, actor: actor)&.id
    end
  rescue StandardError => e
    Rails.logger.warn("edit audit failed for #{self.class.name} ##{id}: #{e.message}")
    []
  end

  # RecordEdit#table_slug is provenance. Registry-backed models already have a
  # slug the grid uses; a plain form model has none, so its table name says
  # where the edit landed.
  def edit_audit_table_slug
    self.class.try(:registry_slug).presence || self.class.table_name
  end

  # Audit and announce one column written outside the normal update path.
  #
  # Reassignable#reassign_to! writes the assignee with update_column so that a
  # record whose validations have since tightened can still be handed to
  # somebody else. That skips callbacks entirely, so a reassignment would
  # otherwise leave no trace in the edit trail and tell no subscriber. Rather
  # than loosen that write, the caller asks for the audit explicitly.
  #
  # Public in effect but private by placement: it is called on self from the
  # concern, not from outside the record.
  def record_out_of_band_edit(column_name, old_value, new_value)
    return if old_value.to_s == new_value.to_s

    actor = { id: Current.user&.dig('employee_id')&.to_s, name: current_user_display_name }
    edit = RecordEdit.capture(row: self, table_slug: edit_audit_table_slug,
                              column_name: column_name.to_s,
                              old_value: old_value, new_value: new_value, actor: actor)

    after_edits_captured([edit&.id].compact)
  rescue StandardError => e
    Rails.logger.warn("out-of-band edit audit failed for #{self.class.name} ##{id}: #{e.message}")
  end

  def current_user_display_name
    return nil unless Current.user

    [Current.user['first_name'], Current.user['last_name']].compact.join(' ').presence
  end
end
