# frozen_string_literal: true

module Aim
  # Drop invoices in from Paperboy instead of the share. Does exactly what the
  # worker's intake does for a dropped file: the PDF goes to the store and one
  # row is inserted. Anyone who holds the AIM app may upload; the BU defaults
  # to their own unit. AIM v2.
  class UploadsController < BaseController
    PDF_TYPES = %w[application/pdf application/x-pdf].freeze

    def new
      @budget_unit = current_user_unit
    end

    def create
      budget_unit = params[:budget_unit].to_s.strip
      files = Array(params[:files]).reject(&:blank?)
      return refuse('Enter the four-digit budget unit.') unless budget_unit.match?(/\A\d{4}\z/)
      return refuse('Choose at least one PDF.') if files.empty?
      return refuse('Only PDF files can be uploaded.') unless files.all? { |file| pdf?(file) }

      stored = files.map { |file| store(file, budget_unit) }
      redirect_to aim_invoices_path(queue: 'received'),
                  notice: "#{pluralize(stored.size, 'invoice')} uploaded. The AI reads them next."
    rescue Aim::MissingConfiguration, SystemCallError, ActiveRecord::RecordInvalid => e
      Rails.logger.error "AIM upload failed: #{e.class}: #{e.message}"
      refuse('The upload could not be stored. Check the AIM share and try again.')
    end

    private

    def store(file, budget_unit)
      Aim::Intake.new.store(file,
                            original_filename: file.original_filename, budget_unit: budget_unit,
                            submitter: submitter_name, owner: { name: owner_name, employee_id: owner_employee_id },
                            actor: current_user_email, source: 'upload').invoice
    end

    def submitter_name = current_user_name || current_user_email

    # Whose queue the invoice goes to: the uploader's, a named person's, or
    # nobody's (the BU's shared queue).
    def owner_name
      return if owner_employee_id.nil?

      Aim::Invoice.employee_name(owner_employee_id) || (submitter_name if owner_employee_id == current_user_employee_id)
    end

    # The owner as a person: the uploader, someone picked the way Emulate picks
    # (an employee id), or nobody -- the BU's shared queue.
    def owner_employee_id
      @owner_employee_id ||= case params[:owner].to_s
                             when 'shared' then nil
                             when 'person' then params[:owner_employee_id].presence&.to_i
                             else current_user_employee_id
                             end
    end

    def pdf?(file)
      PDF_TYPES.include?(file.content_type.to_s.downcase) || File.extname(file.original_filename.to_s).casecmp?('.pdf')
    end

    def refuse(message)
      redirect_to new_aim_upload_path, alert: message
    end

    def pluralize(count, noun) = helpers.pluralize(count, noun)
  end
end
