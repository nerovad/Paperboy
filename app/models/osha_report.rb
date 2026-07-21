# frozen_string_literal: true

class OshaReport < ApplicationRecord
  include TrackableStatus
  include Registry

  enum :status, {
    in_progress: 'in_progress',
    step_1_pending: 'step_1_pending',
    approved: 'approved',
    denied: 'denied'
  }, default: :in_progress

  belongs_to :safety_report, optional: true

  # OSHA gives 8 hours to file the 301 on a reportable incident. Set on
  # reportable reports only — see SafetyReport#create_osha_report!.
  REPORTABLE_FILING_WINDOW = 8.hours

  # Scopes
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }

  # Reportable 301s whose 8-hour window has run out while the report is still a
  # draft, and which haven't already had their one breach notice sent. Drives
  # OshaReportableDeadlineJob. A report that has advanced out of in_progress has
  # been filed, so it can no longer breach.
  scope :reportable_breached, lambda {
    where(status: :in_progress)
      .where.not(reportable_due_at: nil)
      .where(reportable_due_at: ..Time.current)
      .where(reportable_breach_notified_at: nil)
  }

  # Narrow to an Agency → Division → Department → Unit selection. Each level is
  # optional; a blank value leaves that level unfiltered ("all"). The org
  # columns store the GSABSS id values as strings. Powers the OSHA 300 portal
  # filters (300 Log + 300A Summary).
  scope :org_filtered, lambda { |filters|
    filters = (filters || {}).symbolize_keys
    rel = all
    rel = rel.where(agency: filters[:agency]) if filters[:agency].present?
    rel = rel.where(division: filters[:division]) if filters[:division].present?
    rel = rel.where(department: filters[:department]) if filters[:department].present?
    rel = rel.where(unit: filters[:unit]) if filters[:unit].present?
    rel
  }

  # Minimal baseline validations; adjust or remove as needed
  validates :name, :email, presence: true

  # --- Records table: the OSHA 300 Log -------------------------------------
  #
  # A live view over the approved reports, in the same column order as the
  # printed OSHA Form 300. This is the 300 Log — it replaced the standalone
  # screen that used to be a tab of the OSHA 300 portal. Only approved reports
  # are recordable, so the table narrows to them rather than showing drafts and
  # denials. Access reuses the existing 'osha_log' ACL key, so nobody gains the
  # log by way of Records.
  registry_table slug: 'osha-300-log', label: 'OSHA 300 Log',
                 dropdown_key: 'osha_log',
                 includes: :safety_report,
                 scope: -> { where(status: :approved) }

  registry_column :log_case_number, label: 'Case #', kind: :text, filter: :search
  registry_column :name, label: 'Employee Name', kind: :text, filter: :search
  registry_column :job_title, label: 'Job Title', kind: :text, sortable: false
  registry_column :date_of_injury_or_illness, label: 'Date of Injury', kind: :date
  registry_column :what_was_the_employee_doing_just_before_the_incident_occurred,
                  label: 'Activity at Time of Incident', kind: :text
  registry_column :what_was_the_injury_or_illness,
                  label: 'Description of Injury/Illness', kind: :text
  registry_column :died_label, label: 'Death?', kind: :text, sortable: false
  registry_column :days_away_from_work, label: 'Days Away from Work', kind: :text, sortable: false

  # Case number as printed on the log. Falls back to the report id so every row
  # carries a stable identifier — unlike the 300 Log screen's positional
  # fallback, which renumbers whenever the year or org filter changes.
  def log_case_number
    case_number_from_the_log.presence || id.to_s
  end

  # Job title lives on the employee record in GSABSS, which can't be joined
  # across the database boundary, so it's a per-row lookup memoized on the
  # instance.
  def job_title
    return @job_title if defined?(@job_title)

    @job_title = employee_id.present? ? Employee.find_by(employee_id: employee_id)&.job_title : nil
  end

  def died?
    did_employee_die.to_s.casecmp('yes').zero?
  end

  def died_label
    died? ? 'Yes' : 'No'
  end

  # Days away from work, taken from the originating safety report. OSHA caps
  # the count at 180 days per case.
  def days_away_from_work
    last_worked = safety_report&.date_last_worked
    return nil if last_worked.blank?

    end_date = safety_report.date_returned_to_work.presence || Date.current
    (end_date - last_worked).to_i.clamp(0, 180)
  end

  # True once the 8-hour filing window has lapsed on a still-unfiled reportable
  # 301. Drives the overdue flag in the inbox, so it stays true after the breach
  # email has gone out — the row should keep showing as late until it's filed.
  def reportable_overdue?
    reportable_due_at.present? && in_progress? && reportable_due_at <= Time.current
  end

  # For inbox reassignment - returns the current approver's ID
  def current_assignee_id
    approver_id
  end

  # Get the form template for this model (for button configuration)
  def form_template
    @form_template ||= FormTemplate.find_by(class_name: self.class.name)
  end
end
