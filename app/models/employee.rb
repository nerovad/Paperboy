# frozen_string_literal: true

# app/models/employee.rb
class Employee < GsabssBase
  self.table_name = 'Employees'
  self.primary_key = 'id'

  # The GSABSS Employees table was renamed to snake_case columns; `id` is the
  # PK (previously EmployeeID). A small alias preserves the historical
  # employee_id accessor used throughout the app and form models.
  alias_attribute :employee_id, :id

  # Employees has a `type` column (job type / classification) that would
  # otherwise be treated as STI by Rails. Disable that.
  self.inheritance_column = nil

  has_many :employee_groups, foreign_key: 'EmployeeID', primary_key: 'id'
  # disable_joins: Employee_Groups/Groups live in the Paperboy DB while this
  # model lives in GSABSS — Rails cannot JOIN across connections.
  has_many :groups, through: :employee_groups, disable_joins: true

  # Name formats, one place for all of them. The class-level forms take the
  # raw parts, always first name before last name (the order callers pluck
  # them in), so a plucked tuple formats the same way as a record.
  #
  #   full_name     "First Last"        (blank parts dropped, whitespace squished)
  #   sort_name     "Last, First"       (lists sorted by surname)
  #   picker_label  "Last, First (id)"  (employee pickers and search results)
  #   name_with_id  "First Last (id)"
  def self.format_full_name(first_name, last_name) = "#{first_name} #{last_name}".squish
  def self.format_sort_name(first_name, last_name) = "#{last_name}, #{first_name}"
  def self.format_picker_label(id, first_name, last_name) = "#{format_sort_name(first_name, last_name)} (#{id})"

  # The { value:, label:, unit: } hash the employee search endpoints return
  # (COA Employee Lookup, AIM's people pickers).
  def self.search_option(id, first_name, last_name, unit)
    { value: id, label: format_picker_label(id, first_name, last_name), unit: unit }
  end

  # Columns to pluck for .search_option, in its argument order.
  SEARCH_OPTION_COLUMNS = %i[id first_name last_name unit].freeze

  # The current relation as search options: Employee.search_ranked(q).limit(20).search_options
  def self.search_options = pluck(*SEARCH_OPTION_COLUMNS).map { |row| search_option(*row) }

  # Employees whose first name, last name, "First Last" or id contains
  # +term+ (SQL Server; LIKE wildcards in the term are escaped). A blank term
  # matches nobody. Unordered and unlimited: pickers want .search_ranked.
  def self.search(term)
    term = term.to_s.strip
    return none if term.blank?

    where('first_name LIKE :q OR last_name LIKE :q OR CAST(id AS VARCHAR(20)) LIKE :q ' \
          "OR (first_name + ' ' + last_name) LIKE :q",
          q: "%#{sanitize_sql_like(term)}%")
  end

  # .search in pick-list order: the employee whose id is exactly +term+ first,
  # then by surname. Every people picker uses this, so typing a full id always
  # finds that person even when more than a page of other ids contain it.
  def self.search_ranked(term) = search(term).in_search_order(term)

  # The pick-list order on its own, for a relation already narrowed by .search.
  def self.in_search_order(term)
    id = term.to_s.strip
    exact = if id.match?(/\A\d{1,18}\z/)
              [Arel.sql(sanitize_sql_array(['CASE WHEN id = ? THEN 0 ELSE 1 END', id.to_i]))]
            else
              []
            end
    order(*exact, :last_name, :first_name)
  end

  def full_name = self.class.format_full_name(first_name, last_name)
  def sort_name = self.class.format_sort_name(first_name, last_name)
  def picker_label = self.class.format_picker_label(id, first_name, last_name)
  def name_with_id = "#{full_name} (#{id})"

  # Helper method to check group membership
  def in_group?(name)
    groups.exists?(Group_Name: name)
  end

  # Helper to check multiple groups (user needs ANY of them)
  def in_any_group?(*group_names)
    groups.where(Group_Name: group_names).exists?
  end

  # Returns all employee IDs in the reporting chain beneath the given manager
  # (direct reports, their reports, etc.) Does NOT include the manager themselves.
  def self.subordinate_ids(manager_id)
    collected = []
    queue = [manager_id.to_s]

    while queue.any?
      direct_report_ids = where(supervisor_id: queue).pluck(:id).map(&:to_s)
      direct_report_ids -= collected # avoid cycles
      direct_report_ids -= [manager_id.to_s]
      break if direct_report_ids.empty?

      collected.concat(direct_report_ids)
      queue = direct_report_ids
    end

    collected
  end
end
