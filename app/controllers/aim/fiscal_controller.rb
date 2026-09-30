# frozen_string_literal: true

module Aim
  # The Fiscal stage (item f, demo first cut, 2026-09-28): approved invoices
  # reach Fiscal, who record the payment details beside each one
  # (Aim::FiscalRecord), hold what is missing something, and mark the rest
  # ready for the export. The worker's states are untouched: every invoice it
  # has approved belongs here.
  class FiscalController < BaseController
    include Aim::StoredPdf
    include Aim::FiscalEdits

    # Each button posts fiscal_action=<value>, never its label, so a button
    # can be renamed without breaking what it does.
    ACTIONS = {
      'save' => :save_only,
      'hold' => :hold,
      'make_ready' => :make_ready,
      'release' => :release,
      'back_to_review' => :back_to_review,
      'archive' => :archive
    }.freeze

    before_action :require_fiscal
    before_action :set_status, only: :index
    before_action :set_record, only: %i[show update pdf]

    VIEWS = %w[all bu].freeze

    # One status at a time, as one list or grouped by budget unit. The Fiscal
    # Queue starts grouped, the rest as one list.
    def index
      remember_return(:aim_fiscal_page)
      @view = VIEWS.include?(params[:view]) ? params[:view] : default_view
      reading_database("list the Fiscal #{@status} invoices", alert: 'The invoice database could not be read.',
                                                              empty: { records: [], groups: [], stamps: {} }) do
        Aim::FiscalRecord.take_in_approved!
        @records = Aim::FiscalRecord.in_status(@status).to_a.sort_by { |record| [-record.invoice.created_at.to_f, -record.id] }
        @stamps = Aim::FiscalExport.approval_stamps(@records.map(&:invoice_id))
        @groups = fiscal_groups if @view == 'bu'
      end
    end

    def show
      @stamp = Aim::FiscalExport.approval_stamps([@invoice.id])[@invoice.id]
      @pdf_present = stored_pdf_path.present?
      @events = @invoice.events.to_a
      @line = @invoice.coding || @invoice.coding_lines.build(source: 'fiscal')
      @coa = Aim::CoaCodes.new(@invoice.agency!.to_s)
    end

    def update
      action = ACTIONS[params[:fiscal_action].to_s]
      return redirect_to(aim_fiscal_invoice_path(@record.invoice.batch_id), alert: 'Unknown action.') if action.nil?

      Aim::FiscalRecord.transaction do
        save_fields
        send(action)
      end
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      redirect_to aim_fiscal_invoice_path(@record.invoice.batch_id), alert: e.message
    end

    def pdf
      path = stored_pdf_path
      return head :not_found if path.nil?

      send_file path, type: 'application/pdf', disposition: 'inline', filename: Aim::FiscalRecord.file_name_for(@invoice)
    end

    private

    def default_view = @status == 'review' ? 'bu' : 'all'

    def fiscal_groups
      coa = Aim::Units.new
      @records.group_by { |record| record.invoice.budget_unit }.sort_by { |unit, _| unit.to_s }
              .map { |unit, rows| [unit, coa.label(unit), rows] }
    end

    def set_status
      @status = params[:status].presence || 'review'
      return if Aim::FiscalRecord::STATUSES.include?(@status)

      redirect_to aim_fiscal_path, alert: 'Unknown Fiscal list.'
    end

    def set_record
      invoice = Aim::Invoice.find_by(batch_id: params[:id].to_s)
      @record = invoice && Aim::FiscalRecord.find_by(invoice_id: invoice.id)
      @record ||= Aim::FiscalRecord.create!(invoice: invoice) if invoice && Aim::FiscalRecord::APPROVED_STATES.include?(invoice.state)
      @invoice = @record&.invoice
      return if @record

      redirect_to aim_fiscal_path, alert: 'That invoice is not with Fiscal.'
    end

    def fiscal_return_path = remembered_return(:aim_fiscal_page, '/aim/fiscal') { aim_fiscal_path }
    helper_method :fiscal_return_path

    def reason = params[:reason].to_s.squish.presence

    def save_only = back('Saved.')

    def hold
      raise ArgumentError, 'Say why the invoice is on hold.' if reason.blank?

      @record.move_to!('on_hold', actor: current_user_email, note: "reason: #{reason}", hold_reason: reason)
      back('On hold.')
    end

    def make_ready
      @record.move_to!('ready', actor: current_user_email, hold_reason: nil)
      finish('Added to the Report Queue.')
    end

    def release
      @record.move_to!('review', actor: current_user_email, hold_reason: nil)
      back('Released to the Fiscal Queue.')
    end

    def back_to_review
      @record.move_to!('review', actor: current_user_email)
      back('Back in the Fiscal Queue.')
    end

    def archive
      @record.move_to!('archived', actor: current_user_email, archived_at: Time.current)
      finish('Archived.')
    end

    def back(notice) = redirect_to(aim_fiscal_invoice_path(@record.invoice.batch_id), notice: notice)

    def finish(notice) = redirect_to(fiscal_return_path, notice: notice)
  end
end
