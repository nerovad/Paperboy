# frozen_string_literal: true

# app/models/authorized_approver_change.rb
#
# One entry in the parking, badges and keys console's change log: an
# authorization added, edited or removed, by whom, and its scope before and
# after. Written by AuthorizationConsoleController alongside the change itself.
#
# An authorization is stored as one AuthorizedApprover row per service type and
# key type, and an edit replaces those rows. The log works a level up, on the
# whole authorization, so an edit reads as one change rather than a removal
# followed by an addition. Entries are never updated or deleted.
class AuthorizedApproverChange < ApplicationRecord
  ACTIONS = %w[added edited removed].freeze

  # Scope fields in display order, with the heading each is shown under.
  FIELDS = {
    'employee_id' => 'Employee',
    'service_types' => 'Service Types',
    'key_types' => 'Key Types',
    'budget_units' => 'Budget Units',
    'locations' => 'Locations'
  }.freeze

  serialize :scope_before, coder: JSON
  serialize :scope_after, coder: JSON

  validates :action, inclusion: { in: ACTIONS }
  validates :employee_id, :department_id, :changed_by, presence: true

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # The scope of one authorization, from the rows that make it up.
  def self.snapshot(rows)
    rows = Array(rows)
    return nil if rows.empty?

    first = rows.first
    { 'employee_id' => first.employee_id.to_s,
      'service_types' => rows.map(&:service_type).uniq.sort,
      'key_types' => rows.filter_map(&:key_type).uniq.sort,
      'budget_units' => first.all_budget_units? ? 'All' : first.budget_units.to_s.split(',').map(&:strip).sort,
      'locations' => locations_of(rows) }
  end

  # Locations are held on the Facility Keys rows only.
  def self.locations_of(rows)
    return 'All' if rows.any?(&:all_locations?)

    rows.flat_map { |row| Array(row.locations) }.uniq.sort
  end

  # Logs one change. `before` and `after` are the rows of the authorization
  # either side of it; an edit that altered nothing writes no entry.
  def self.record!(action:, changed_by:, before: [], after: [])
    scope_before = snapshot(before)
    scope_after = snapshot(after)
    return nil if scope_before == scope_after

    subject = Array(after).first || Array(before).first
    create!(action: action, changed_by: changed_by.to_s, employee_id: subject.employee_id.to_s,
            department_id: subject.department_id.to_s, scope_before: scope_before, scope_after: scope_after)
  end

  # [heading, before, after] for each scope field worth showing: the ones that
  # differ on an edit, the ones that hold something on an add or a removal.
  def differences
    FIELDS.filter_map do |field, heading|
      before = self.class.display(field, scope_before&.dig(field))
      after = self.class.display(field, scope_after&.dig(field))
      next if before == after || (field == 'employee_id' && action != 'edited')

      [heading, before, after]
    end
  end

  def self.display(field, value)
    labels = { 'service_types' => AuthorizedApprover::SERVICE_TYPES, 'key_types' => AuthorizedApprover::KEY_TYPES }[field]
    Array(value).map { |item| labels&.fetch(item, item) || item }.join(', ')
  end
end
