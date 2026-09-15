# frozen_string_literal: true

# app/mailers/report_mailer.rb
class ReportMailer < ApplicationMailer
  default from: ENV['SMTP_FROM_ADDRESS'] || 'noreply@ventura.org'

  def report_ready(employee, zip_filename, submission_count, form_type, start_date, end_date)
    @employee = employee
    @submission_count = submission_count
    @form_type = form_type.humanize
    @start_date = start_date
    @end_date = end_date
    @zip_filename = File.basename(zip_filename)

    # Attach the zip file
    attachments[@zip_filename] = File.read(zip_filename)

    mail(
      to: employee.email,
      subject: "Your Report is Ready - #{@form_type} (#{submission_count} submissions)"
    )
  end

  def no_submissions_found(employee, form_type, start_date, end_date)
    @employee = employee
    @form_type = form_type.humanize
    @start_date = start_date
    @end_date = end_date

    mail(
      to: employee.email,
      subject: "No Submissions Found - #{@form_type}"
    )
  end

  # The audit-trail export from the Reports page. Its subject counts entries
  # rather than submissions; a single submission can account for a dozen rows.
  def audit_export_ready(employee, file_path, summary, start_date, end_date)
    @employee = employee
    @summary = summary
    @start_date = start_date
    @end_date = end_date
    @filename = File.basename(file_path)
    @total = summary.values.sum

    attachments[@filename] = File.binread(file_path)

    mail(
      to: employee.email,
      subject: "Your Audit History Export is Ready (#{@total} #{'entry'.pluralize(@total)})"
    )
  end

  def no_audit_history_found(employee, sources, start_date, end_date)
    @employee = employee
    @labels = Array(sources).filter_map { |source| Forms::AuditExport::SOURCES[source.to_s] }
    @start_date = start_date
    @end_date = end_date

    mail(
      to: employee.email,
      subject: 'No Audit History Found'
    )
  end

  # A scheduled Records grid export. `csv` is the file's contents; a view that
  # matches no rows still sends, headers only, so the owner can tell "nothing
  # matched this week" from "the schedule stopped".
  def record_export_ready(employee, schedule, csv, row_count)
    @employee = employee
    @schedule = schedule
    @row_count = row_count
    @filename = RecordsCsv.filename(schedule.table)

    attachments[@filename] = { mime_type: 'text/csv', content: csv }

    mail(
      to: employee.email,
      subject: "#{schedule.table_label} export (#{row_count} #{'row'.pluralize(row_count)})"
    )
  end

  # The schedule's owner can no longer open its table, so it was paused.
  def record_export_paused(employee, schedule)
    @employee = employee
    @schedule = schedule

    mail(
      to: employee.email,
      subject: "Scheduled export paused - #{schedule.table_label}"
    )
  end

  def record_export_failed(employee, schedule, error_message)
    @employee = employee
    @schedule = schedule
    @error_message = error_message

    mail(
      to: employee.email,
      subject: "Scheduled export failed - #{schedule.table_label}"
    )
  end

  def report_generation_failed(employee, form_type, error_message)
    @employee = employee
    @form_type = form_type.humanize
    @error_message = error_message

    mail(
      to: employee.email,
      subject: "Report Generation Failed - #{@form_type}"
    )
  end
end
