# frozen_string_literal: true

module Aim
  # Drop invoices in from Paperboy instead of the share. Does exactly what the
  # worker's intake does for a dropped file: the PDF goes to the store and one
  # row is inserted. Anyone signed in may upload, usually for someone else;
  # the BU is picked from AIM's budget units (Chart of Accounts units an AIM
  # Admin has chosen, other agencies' too, since GSA sometimes processes
  # theirs), and defaults to their own unit. An invoice for someone who is
  # away goes to whoever covers for them. AIM v2.
  class UploadsController < BaseController
    # What the bytes must be, whatever the file is called or the browser
    # declares.
    PDF_TYPE = 'application/pdf'

    def new
      @budget_unit = current_user_unit
      @units = Aim::Units.new
      # Someone with no queue of their own uploads to someone else's.
      @has_queue = helpers.aim_has_queue?
    end

    def create
      budget_unit = params[:budget_unit].to_s.strip
      files = Array(params[:files]).reject(&:blank?)
      return refuse('Pick the budget unit from the list.') unless Aim::Units.new.valid?(budget_unit)
      return refuse('Choose at least one PDF.') if files.empty?
      return refuse('Only PDF files can be uploaded.') unless files.all? { |file| pdf?(file) }
      return refuse('Choose the person whose queue it goes to.') if params[:owner] == 'person' && owner_employee_id.nil?
      return refuse('That person is not in AIM, so they have no queue.') if outsider_chosen?
      return refuse("They do not work in #{budget_unit}. Pick one of their budget units.") if outside_their_units?(budget_unit)

      stored = files.map { |file| store(file, budget_unit) }
      redirect_to new_aim_upload_path,
                  notice: "#{pluralize(stored.size, 'invoice')} uploaded. The AI reads them next."
    rescue Aim::MissingConfiguration, SystemCallError, ActiveRecord::RecordInvalid => e
      Rails.logger.error "AIM upload failed: #{e.class}: #{e.message}"
      refuse('The upload could not be saved. Try again.')
    end

    private

    def store(file, budget_unit)
      invoice = Aim::Intake.new.store(file,
                                      original_filename: file.original_filename, budget_unit: budget_unit,
                                      submitter: submitter_name, owner: { name: owner_name, employee_id: owner_employee_id },
                                      actor: current_user_email, source: 'upload').invoice
      invoice.hand_to_cover!(by: current_user_employee_id)
      invoice
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

    def outsider_chosen? = params[:owner] == 'person' && !Aim::Users.member?(owner_employee_id)

    # The BU follows the person (2026-09-29): an invoice for someone goes in
    # one of their budget units. Someone with none recorded is not held to it.
    def outside_their_units?(budget_unit)
      return false unless params[:owner] == 'person' && owner_employee_id

      theirs = Aim::Users.budget_units_of(owner_employee_id)
      theirs.any? && theirs.exclude?(budget_unit)
    end

    # Sniffed from the content with Marcel, as the DAM's watch-folder intake
    # does (Dam::WatchFolderIngest). The name and the declared type are left
    # out: a renamed Word file is not a PDF, and a PDF is one whatever it is
    # called.
    def pdf?(file)
      io = file.respond_to?(:tempfile) ? file.tempfile : file
      io.rewind
      Marcel::MimeType.for(io) == PDF_TYPE
    ensure
      io&.rewind
    end

    def refuse(message)
      redirect_to new_aim_upload_path, alert: message
    end

    def pluralize(count, noun) = helpers.pluralize(count, noun)
  end
end
