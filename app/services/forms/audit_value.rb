# frozen_string_literal: true

# app/services/forms/audit_value.rb

module Forms
  # Turns a raw audited column value back into something a person can read.
  #
  # RecordEdit stores whatever string the column held, so an unhelped edit trail
  # says `agency: 12 -> 15`. The forms all draw their org and people fields from
  # the same GSABSS tables under the same column names, so one table of lookups
  # covers every form rather than each one teaching the trail about itself.
  #
  # Every lookup is best-effort: GSABSS is a second database and a stale id may
  # no longer resolve, so a failed lookup falls back to the raw value rather
  # than blanking the trail or raising in a view.
  class AuditValue
    EMPTY = '—'

    # Column name => which catalog names its values.
    LOOKUPS = {
      'agency' => :agency, 'job_agency' => :agency,
      'impacted_agency' => :agency, 'impacted_customers' => :agency,
      'division' => :division, 'job_division' => :division,
      'department' => :department, 'job_department' => :department,
      'unit' => :unit, 'job_unit' => :unit,
      'employee_id' => :employee, 'supervisor_id' => :employee,
      'assigned_manager_id' => :employee, 'staff_involved' => :employee,
      'impacted_employee' => :employee
    }.freeze

    # Columns the forms store as a comma-joined list (multi-selects normalized
    # on the way in — see the params methods on the form controllers).
    MULTI_VALUE = %w[staff_involved impacted_customers impacted_agency impacted_employee building].freeze

    DATE_COLUMN = /(\A|_)date(s)?\z|_at\z|_on\z/

    def initialize
      @cache = {}
    end

    def call(column, raw)
      value = raw.to_s.strip
      return EMPTY if value.blank?

      if MULTI_VALUE.include?(column)
        value.split(',').map { |part| single(column, part.strip) }.compact_blank.join(', ').presence || EMPTY
      else
        single(column, value)
      end
    end

    private

    def single(column, value)
      return EMPTY if value.blank?
      return 'Yes' if value == 'true'
      return 'No' if value == 'false'

      labelled = lookup(LOOKUPS[column], value)
      return labelled if labelled

      column.match?(DATE_COLUMN) ? as_date(value) : value
    end

    def lookup(kind, value)
      return nil unless kind

      @cache.fetch([kind, value]) do
        @cache[[kind, value]] = resolve(kind, value)
      end
    end

    def resolve(kind, value)
      name = case kind
             when :agency then Coa::Agency.find_by(agency_id: value)&.long_name
             when :division then Coa::Division.find_by(division_id: value)&.long_name
             when :department then Coa::Department.find_by(department_id: value)&.long_name
             when :unit then Coa::Unit.find_by(unit_id: value)&.long_name
             when :employee then employee_name(value)
             end

      name.present? ? "#{value} - #{name}" : nil
    rescue StandardError
      nil
    end

    def employee_name(value)
      employee = Employee.find_by(id: value)
      return nil unless employee

      [employee.first_name, employee.last_name].compact_blank.join(' ').presence
    end

    def as_date(value)
      parsed = Time.zone.parse(value)
      parsed ? I18n.l(parsed, format: :long) : value
    rescue StandardError
      value
    end
  end
end
