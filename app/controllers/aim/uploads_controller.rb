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
      problem = upload_problem(budget_unit, files)
      return refuse(problem) if problem

      stored = files.map { |file| store(file, budget_unit) }
      redirect_to new_aim_upload_path, notice: "#{pluralize(stored.size, 'invoice')} uploaded. #{where_they_went}"
    rescue Aim::MissingConfiguration, SystemCallError, ActiveRecord::RecordInvalid => e
      Rails.logger.error "AIM upload failed: #{e.class}: #{e.message}"
      refuse('The upload could not be saved. Try again.')
    end

    private

    def store(file, budget_unit)
      owner = fiscal? ? nil : { name: owner_name, employee_id: owner_employee_id }
      invoice = Aim::Intake.new.store(file,
                                      original_filename: file.original_filename, budget_unit: budget_unit,
                                      submitter: submitter_name, owner: owner,
                                      actor: current_user_email, source: 'upload', manual: manual?, fiscal: fiscal?).invoice
      if fiscal?
        invoice.events.create!(action: 'fiscal', actor: current_user_email,
                               note: "Uploaded straight to Fiscal#{manual? ? ', typed in by Fiscal' : ' after the AI reads it'}; " \
                                     'no approval queue, approved by its uploader')
      else
        invoice.hand_to_cover!(by: current_user_employee_id)
      end
      invoice
    end

    def where_they_went
      if fiscal? && manual? then 'They are in the Fiscal Queue, flagged Manual Data Entry Needed.'
      elsif fiscal? then 'The AI reads them next, then they go straight to Fiscal.'
      elsif manual? then 'They are in the queue, flagged Manual Data Entry Needed.'
      else 'The AI reads them next.'
      end
    end

    # Why this upload cannot go ahead, or nil.
    def upload_problem(budget_unit, files)
      if !Aim::Units.new.valid?(budget_unit) then 'Pick the budget unit from the list.'
      elsif files.empty? then 'Choose at least one PDF.'
      elsif !files.all? { |file| pdf?(file) } then 'Only PDF files can be uploaded.'
      elsif fiscal? then fiscal_refusal(budget_unit)
      elsif params[:owner] == 'person' && owner_employee_id.nil? then 'Choose the person whose queue it goes to.'
      elsif outsider_chosen? then 'That person is not in AIM, so they have no queue.'
      elsif outside_their_units?(budget_unit) then "They do not work in #{budget_unit}. Pick one of their budget units."
      elsif manual? && !fiscal? then manual_refusal(budget_unit)
      end
    end

    def submitter_name = current_user_name || current_user_email

    # Two choices (#131): where it goes -- a queue, or straight to Fiscal
    # (owner=fiscal) -- and whether the AI reads it or someone types it in
    # (skip_ai).
    def manual? = params[:skip_ai] == '1'

    def fiscal? = params[:owner] == 'fiscal'

    # Straight to Fiscal: AIM Admins, and Fiscal people for the budget units
    # their agency groups work.
    def fiscal_refusal(budget_unit)
      return 'Only AIM Admins and Fiscal can upload straight to Fiscal.' unless helpers.aim_fiscal?
      return if group_serves_unit?(Aim::Units.new.agency_of(budget_unit), budget_unit)

      "#{budget_unit} is outside your agency groups."
    end

    # Who may skip the AI: anyone with a queue, into their own; AIM Admins and
    # the BU's Admins into anyone else's, or the shared queue.
    def manual_refusal(budget_unit)
      own = owner_employee_id.present? && owner_employee_id == current_user_employee_id
      return if own && helpers.aim_has_queue?
      return if helpers.aim_queue_access? || helpers.aim_bu_admin_units&.include?(budget_unit)

      'Only AIM Admins and the BU\'s Admins can skip the AI for someone else\'s queue.'
    end

    # Whose queue the invoice goes to: the uploader's, a named person's, or
    # nobody's (the BU's shared queue, or straight to Fiscal).
    def owner_name
      return if owner_employee_id.nil?

      Aim::Invoice.employee_name(owner_employee_id) || (submitter_name if owner_employee_id == current_user_employee_id)
    end

    # The owner as a person: the uploader, someone picked the way Emulate picks
    # (an employee id), or nobody -- the BU's shared queue.
    def owner_employee_id
      @owner_employee_id ||= case params[:owner].to_s
                             when 'shared', 'fiscal' then nil
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
