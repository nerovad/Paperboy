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
end
