# frozen_string_literal: true

class UserSetting < ApplicationRecord
  # Per-user, per-page table layouts for the Inbox and Submissions "My Work"
  # tables (see TableColumns). Mirrors SavedSearch#filters JSON storage.
  serialize :column_prefs, coder: JSON

  validates :employee_id, presence: true, uniqueness: true

  # Ordered list of column descriptors for a page (:inbox / :submissions).
  # Falls back to the normalized default layout when the user hasn't saved one.
  # Each descriptor is either a built-in key (String) or a custom-field Hash
  # like { "type" => "field", "form" => "LeaveOfAbsenceForm",
  #        "field" => "reason", "label" => "Leave Reason" }.
  def layout_for(page)
    stored = (column_prefs || {})[page.to_s]
    return TableColumns.default_layout(page) unless stored.is_a?(Array) && stored.any?

    TableColumns.sanitize_layout(page, stored)
  end

  # Persist a sanitized layout for a page, leaving the other page untouched.
  def set_layout(page, fields)
    prefs = (column_prefs || {}).dup
    prefs[page.to_s] = TableColumns.sanitize_layout(page, fields)
    self.column_prefs = prefs
    save
  end

  # Fetch (or build) the settings row for an employee.
  def self.for_employee(employee_id)
    find_or_initialize_by(employee_id: employee_id.to_s)
  end

  # Of `employee_ids`, the ones whose owner has opted in to inbox email
  # notifications. Employees with no settings row are absent from the result:
  # the column defaults to false, so nobody is emailed until they ask to be.
  # Kept as a single pluck because the caller (TrackableStatus) resolves an
  # approver pool that can run to a whole group.
  def self.notifiable_employee_ids(employee_ids)
    ids = Array(employee_ids).map(&:to_s).compact_blank.uniq
    return [] if ids.empty?

    where(employee_id: ids, inbox_email_notifications: true).pluck(:employee_id)
  end

  # Which DAM storage location this person's uploads default to, or nil for
  # "follow the library default". Read straight off the column rather than
  # through a row, because the DAM asks on every ingest and most people never
  # set one. Resolution — including what happens when the chosen location is
  # later disabled — belongs to Dam::StorageLocation.for_upload_by.
  def self.dam_storage_location_id_for(employee_id)
    where(employee_id: employee_id.to_s).pick(:dam_storage_location_id)
  end
end
