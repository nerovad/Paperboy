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
      to: employee.Email,
      subject: "Your Report is Ready - #{@form_type} (#{submission_count} submissions)"
    )
  end

  def no_submissions_found(employee, form_type, start_date, end_date)
    @employee = employee
    @form_type = form_type.humanize
    @start_date = start_date
    @end_date = end_date

    mail(
      to: employee.Email,
      subject: "No Submissions Found - #{@form_type}"
    )
  end

  def report_generation_failed(employee, form_type, error_message)
    @employee = employee
    @form_type = form_type.humanize
    @error_message = error_message

    mail(
      to: employee.Email,
      subject: "Report Generation Failed - #{@form_type}"
    )
  end
end
