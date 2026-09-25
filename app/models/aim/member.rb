# frozen_string_literal: true

module Aim
  # Someone an AIM admin has added on the Admin screen. Until the switchover
  # ends, the AIM groups still count too (Aim::Users.all); this is the list
  # that replaces them.
  class Member < Record
    validates :employee_id, presence: true, uniqueness: true

    # Invoices that keep a person from being removed: the ones they own that a
    # person still has to act on. Approved and exporting ones are in the
    # worker's hands and need no owner.
    HANDS_OFF_STATES = %w[approved exporting].freeze

    def self.open_invoices_of(employee_id)
      Aim::Invoice.where(assigned_employee_id: employee_id)
                  .where.not(state: Aim::Invoice::TERMINAL_STATES + HANDS_OFF_STATES)
    end

    # The switchover's first step: everyone who works AIM through a group gets
    # a row, so dropping the groups later takes nobody's access away. Safe to
    # run again. Returns how many were added.
    def self.seed_from_groups!(added_by:)
      existing = pluck(:employee_id).to_set
      missing = Aim::Users.group_employee_ids.reject { |id| existing.include?(id) }
      missing.each { |id| create!(employee_id: id, added_by: added_by) }
      missing.size
    end

    # Adds everyone in a CSV with an employee_id column (item a.1c; the Fusion
    # GSA users are docs/aim/fusion_gsa_users.csv). Safe to run again: people
    # already on the list are left alone. Returns [added, kept, unknown], the
    # last being ids with no GSABSS employee, which are never added.
    def self.import_csv!(path, added_by:)
      ids = CSV.read(path, headers: true).filter_map { |row| row['employee_id'].to_s[/\A\d+\z/]&.to_i }.uniq
      known = Employee.where(id: ids).pluck(:id).to_set
      existing = where(employee_id: ids).pluck(:employee_id).to_set
      added = ids.select { |id| known.include?(id) && !existing.include?(id) }
      added.each { |id| create!(employee_id: id, added_by: added_by) }
      [added.size, existing.size, ids.reject { |id| known.include?(id) }]
    end

    def employee
      @employee ||= Employee.find_by(id: employee_id)
    end

    def open_invoices = self.class.open_invoices_of(employee_id)
  end
end
