# frozen_string_literal: true

# app/jobs/audit_export_job.rb

require 'zip'

# Builds the audit-trail spreadsheets the Reports page asks for and mails them.
#
# Deliberately shaped like ReportGenerationJob: the requester gets an email
# with the file attached rather than a download, because an export covering
# every form somebody can see is not a request you want to hold a browser
# connection open for.
#
# One source produces a bare CSV; several produce a ZIP of one CSV each, so a
# spreadsheet never has to hold three different sets of columns at once.
class AuditExportJob < ApplicationJob
  queue_as :default

  def perform(employee_id, form_types, sources, start_date, end_date)
    employee = Employee.find(employee_id)
    start_date = Date.parse(start_date)
    end_date = Date.parse(end_date)
    path = nil

    tables = build_tables(form_types, sources, start_date, end_date).select(&:any?)

    if tables.empty?
      ReportMailer.no_audit_history_found(employee, sources, start_date, end_date).deliver_now
      return
    end

    path = write_attachment(tables, start_date, end_date)
    ReportMailer.audit_export_ready(employee, path, summary(tables), start_date, end_date).deliver_now
  rescue StandardError => e
    Rails.logger.error "Audit export failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    ReportMailer.report_generation_failed(Employee.find(employee_id), 'audit_export', e.message).deliver_now
  ensure
    FileUtils.rm_f(path) if path
  end

  private

  # The form types were permission-checked when the export was requested; an
  # unresolvable one is dropped rather than raised on, so a template renamed
  # since the request was queued costs one form, not the whole export.
  def build_tables(form_types, sources, start_date, end_date)
    models = Array(form_types).filter_map { |form_type| Forms::AuditExport.model_for(form_type) }

    Forms::AuditExport.new(model_classes: models, sources: sources,
                           start_date: start_date, end_date: end_date).tables
  end

  def summary(tables)
    tables.to_h { |table| [table.label, table.rows.size] }
  end

  def write_attachment(tables, start_date, end_date)
    dir = Rails.root.join('tmp/reports')
    FileUtils.mkdir_p(dir)
    stamp = "#{start_date.strftime('%Y%m%d')}_to_#{end_date.strftime('%Y%m%d')}_#{Time.current.to_i}"

    tables.one? ? write_csv(dir, tables.first, stamp) : write_zip(dir, tables, stamp)
  end

  def write_csv(dir, table, stamp)
    path = dir.join("#{table.source}_#{stamp}.csv")
    File.write(path, table.to_csv)
    path
  end

  def write_zip(dir, tables, stamp)
    path = dir.join("audit_history_#{stamp}.zip")
    FileUtils.rm_f(path)

    Zip::File.open(path, create: true) do |zipfile|
      tables.each do |table|
        zipfile.get_output_stream(table.filename) { |stream| stream.write(table.to_csv) }
      end
    end

    path
  end
end
