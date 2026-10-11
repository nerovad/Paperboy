# frozen_string_literal: true

class UserSetting < ApplicationRecord
  # Per-user, per-page table layouts for the Inbox and Submissions "My Work"
  # tables (see TableColumns). Mirrors SavedSearch#filters JSON storage.
  serialize :column_prefs, coder: JSON

  # The forms this person has taken off their own sidebar, by the key the form
  # ACL knows each one by (see FormCatalog#key_for). A preference only — a
  # hidden form is still listed in the Form Library and still found by a
  # sidebar search that asks for hidden forms.
  serialize :hidden_form_keys, coder: JSON

  # The searches a person can star as their Paperboy start page. Quick Search
  # is the home page and its sidebar; Advanced Search is the Form Library.
  SEARCH_MODES = %w[quick advanced].freeze

  validates :employee_id, presence: true, uniqueness: true

  # Never having chosen, or holding a value this version does not know, is
  # Quick Search — the page Paperboy has always opened on.
  def search_mode
    SEARCH_MODES.include?(default_search_mode) ? default_search_mode : 'quick'
  end

  def self.search_mode_for(employee_id)
    new(default_search_mode: where(employee_id: employee_id.to_s).pick(:default_search_mode)).search_mode
  end

  def hidden_form_key_list
    Array(hidden_form_keys).map(&:to_s)
  end

  # Hides or restores one form, leaving the rest of the list as it was.
  def set_form_hidden(form_key, hidden)
    keys = hidden_form_key_list - [form_key.to_s]
    keys << form_key.to_s if hidden
    self.hidden_form_keys = keys
    save
  end

  # Read straight off the column: the sidebar asks on every page, and most
  # people never hide anything.
  def self.hidden_form_keys_for(employee_id)
    Array(where(employee_id: employee_id.to_s).pick(:hidden_form_keys)).map(&:to_s)
  end

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
