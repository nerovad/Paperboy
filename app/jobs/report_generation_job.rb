# app/jobs/report_generation_job.rb
require 'zip'
require 'prawn'
require 'csv'

class ReportGenerationJob < ApplicationJob
  queue_as :default

  def perform(employee_id, form_type, start_date, end_date, format, status = nil)
    employee = Employee.find(employee_id)
    start_date = Date.parse(start_date)
    end_date = Date.parse(end_date)

    # Get submissions for the specified form and date range
    submissions = get_submissions(form_type, start_date, end_date, status)

    if submissions.empty?
      ReportMailer.no_submissions_found(employee, form_type, start_date, end_date).deliver_now
      return
    end

    # Branch based on format
    if format == 'csv'
      # Generate CSV
      csv_filename = generate_csv(submissions, form_type, start_date, end_date)
      
      # Send email with CSV attachment
      ReportMailer.report_ready(employee, csv_filename, submissions.count, form_type, start_date, end_date).deliver_now
      
      # Clean up CSV file
      File.delete(csv_filename) if File.exist?(csv_filename)
    else
      # Generate PDFs (original logic)
      pdf_files = generate_pdfs(submissions, form_type)
      
      # Create zip file
      zip_filename = create_zip_file(pdf_files, form_type, start_date, end_date)
      
      # Send email with ZIP attachment
      ReportMailer.report_ready(employee, zip_filename, submissions.count, form_type, start_date, end_date).deliver_now
      
      # Clean up temporary files
      cleanup_temp_files(pdf_files)
      File.delete(zip_filename) if File.exist?(zip_filename)
    end
  rescue StandardError => e
    Rails.logger.error "Report generation failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    ReportMailer.report_generation_failed(
      Employee.find(employee_id), 
      form_type, 
      e.message
    ).deliver_now
  end

  private

  def get_submissions(form_type, start_date, end_date, status = nil)
    model_class = form_type_to_model(form_type)
    
    # Check which date column exists in the model
    date_column = if model_class.column_names.include?('SubmittedAt')
      'SubmittedAt'
    elsif model_class.column_names.include?('CreatedAt')
      'CreatedAt'
    elsif model_class.column_names.include?('created_at')
      'created_at'
    else
      'CreatedAt' # Default fallback
    end
    
    # Build base query with date range
    query = model_class.where("#{date_column} >= ? AND #{date_column} <= ?", 
                              start_date.beginning_of_day, 
                              end_date.end_of_day)
    
    # Add status filter if provided
    if status.present? && model_class.column_names.include?('status')
      query = query.where(status: status.to_i)
    end
    
    query.order("#{date_column} DESC")
  end

  def form_type_to_model(form_type)
    # form_type is the tableized class name (e.g., "parking_lot_submissions")
    # Find the template whose class_name tableizes to this value
    template = FormTemplate.all.find { |t| t.class_name.tableize == form_type }
    
    unless template
      raise "Unknown form type: #{form_type}"
    end
    
    # Constantize the class name to get the actual model class
    begin
      template.class_name.constantize
    rescue NameError
      raise "Model class not found for form type: #{form_type} (#{template.class_name})"
    end
  end

  def generate_csv(submissions, form_type, start_date, end_date)
    # Create filename
    csv_filename = Rails.root.join(
      'tmp',
      'reports',
      "#{form_type}_#{start_date.strftime('%Y%m%d')}_to_#{end_date.strftime('%Y%m%d')}_#{Time.current.to_i}.csv"
    )
    
    # Ensure directory exists
    FileUtils.mkdir_p(File.dirname(csv_filename))
    
    # Get all attribute names from the first submission
    headers = submissions.first.attributes.keys
    
    # Generate CSV
    CSV.open(csv_filename, 'wb') do |csv|
      # Write headers
      csv << headers
      
      # Write each submission as a row
      submissions.each do |submission|
        row = headers.map do |attr|
          value = submission.send(attr)
          
          # Format the value appropriately
          case value
          when Time, DateTime
            value.strftime('%Y-%m-%d %H:%M:%S')
          when Date
            value.strftime('%Y-%m-%d')
          when TrueClass
            'Yes'
          when FalseClass
            'No'
          when nil
            ''
          else
            value.to_s
          end
        end
        
        csv << row
      end
    end
    
    csv_filename
  end

  def generate_pdfs(submissions, form_type)
    pdf_files = []
    temp_dir = Rails.root.join('tmp', 'reports', SecureRandom.uuid)
    FileUtils.mkdir_p(temp_dir)

    submissions.each_with_index do |submission, index|
      begin
        pdf_content = generate_pdf_for_submission(submission, form_type)
        
        # Create filename with submission ID and date
        filename = "#{form_type}_#{submission.id}_#{Time.current.strftime('%Y%m%d')}.pdf"
        filepath = temp_dir.join(filename)
        
        File.open(filepath, 'wb') do |file|
          file.write(pdf_content)
        end
        
        pdf_files << filepath
      rescue StandardError => e
        Rails.logger.error "Failed to generate PDF for #{form_type} ##{submission.id}: #{e.message}"
        # Continue with other submissions
      end
    end

    pdf_files
  end

  def generate_pdf_for_submission(submission, form_type)
    Prawn::Document.new(page_size: 'LETTER', margin: 50) do |pdf|
      # Header
      pdf.font 'Helvetica', size: 20, style: :bold
      pdf.text 'Ventura County GSA', align: :center
      pdf.move_down 5
      
      pdf.font 'Helvetica', size: 10
      pdf.text "Generated: #{Time.current.strftime('%B %d, %Y at %I:%M %p')}", align: :center
      pdf.move_down 20
      
      # Form Title
      pdf.font 'Helvetica', size: 16, style: :bold
      pdf.text form_type.humanize, color: '0D6EFD'
      pdf.stroke_horizontal_rule
      pdf.move_down 20
      
      # Submission Details
      pdf.font 'Helvetica', size: 12
      
      # Basic Info
      pdf.text "Submission ID: #{submission.id}", style: :bold
      pdf.move_down 5
      
      # Created/Submitted Date
      date_field = submission.try(:SubmittedAt) || submission.try(:CreatedAt) || submission.try(:created_at)
      if date_field
        pdf.text "Date: #{date_field.strftime('%B %d, %Y at %I:%M %p')}"
        pdf.move_down 15
      end
      
      # All Attributes
      submission.attributes.each do |key, value|
        next if key == 'id' || key =~ /password|token/i
        next if value.nil?
        
        pdf.font 'Helvetica', size: 10, style: :bold
        pdf.text key.humanize, color: '495057'
        pdf.move_down 2
        
        pdf.font 'Helvetica', size: 10, style: :normal
        value_text = case value
        when Time, DateTime, Date
          value.strftime('%B %d, %Y')
        when TrueClass
          'Yes'
        when FalseClass
          'No'
        else
          value.to_s
        end
        
        pdf.text value_text.presence || 'N/A', color: '212529'
        pdf.move_down 10
      end
      
      # Footer
      pdf.move_down 30
      pdf.stroke_horizontal_rule
      pdf.move_down 10
      pdf.font 'Helvetica', size: 8
      pdf.text 'Paperboy - Ventura County General Services Agency', align: :center, color: '6C757D'
      pdf.text 'This document was automatically generated', align: :center, color: '6C757D'
    end.render
  end

  def create_zip_file(pdf_files, form_type, start_date, end_date)
    zip_filename = Rails.root.join(
      'tmp',
      'reports',
      "#{form_type}_#{start_date.strftime('%Y%m%d')}_to_#{end_date.strftime('%Y%m%d')}_#{Time.current.to_i}.zip"
    )

    Zip::File.open(zip_filename, create: true) do |zipfile|
      pdf_files.each do |pdf_file|
        zipfile.add(File.basename(pdf_file), pdf_file)
      end
    end

    zip_filename
  end

  def cleanup_temp_files(pdf_files)
    pdf_files.each do |file|
      File.delete(file) if File.exist?(file)
    end
    
    # Clean up the temp directory if empty
    temp_dir = File.dirname(pdf_files.first) if pdf_files.any?
    Dir.rmdir(temp_dir) if temp_dir && Dir.exist?(temp_dir) && Dir.empty?(temp_dir)
  rescue StandardError => e
    Rails.logger.error "Failed to cleanup temp files: #{e.message}"
  end
end
