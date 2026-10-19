# frozen_string_literal: true

module Aim
  # Find an invoice (#180), from the AIM Dashboard and the Fiscal Dashboard:
  # every invoice the person may already open, whatever its queue. AIM Admins
  # search what Managing serves; someone without queue access, what they own;
  # Fiscal, the Fiscal records of their agency groups. An AIM #, or a quick
  # search with one answer, opens the invoice straight away.
  class FindController < BaseController
    include Aim::FiscalGroupScope

    before_action :require_fiscal, only: :fiscal

    def index
      @finder = Aim::InvoiceFinder.new(params)
      @invoices = []
      return unless @finder.searching?

      reading_database('find invoices', alert: 'The invoice database could not be read.', empty: { invoices: [] }) do
        scope = @finder.invoices(searchable)
        scope = scope.in_queue(params[:where]) if Aim::Invoice::QUEUES.key?(params[:where].to_s)
        @invoices = @finder.fetch(scope.newest_first)
        @fiscal = Aim::FiscalRecord.where(invoice_id: @invoices.map(&:id)).pluck(:invoice_id, :status).to_h
      end
      open_the_one(@invoices) { |invoice| aim_invoice_path(invoice.batch_id, queue: invoice.queue) }
    end

    def fiscal
      @finder = Aim::InvoiceFinder.new(params)
      @records = []
      return unless @finder.searching?

      reading_database('find Fiscal invoices', alert: 'The invoice database could not be read.', empty: { records: [] }) do
        records = Aim::FiscalRecord.includes(:invoice).joins(:invoice).served_by(@finder.invoices(served_invoices))
        records = records.where(status: params[:where]) if Aim::FiscalRecord::STATUSES.include?(params[:where].to_s)
        @records = @finder.fetch(records.order(Aim::Invoice.arel_table[:created_at].desc), invoice: :invoice.to_proc)
        @stamps = Aim::FiscalExport.approval_stamps(@records.map(&:invoice_id))
      end
      open_the_one(@records.map(&:invoice)) { |invoice| aim_fiscal_invoice_path(invoice.batch_id) }
    end

    private

    # AIM Admins: what Managing serves. Anyone else: their own invoices.
    def searchable
      return helpers.aim_agency_groups.invoices(helpers.aim_managing_groups) if helpers.aim_queue_access?

      Aim::Invoice.owned_by(current_user_employee_id)
    end

    # A quick search (with or without filters) that found exactly one opens
    # it; filters alone list it, so the person sees what they asked for.
    def open_the_one(invoices)
      return unless invoices.one? && @finder.criteria.key?(:q)

      redirect_to yield(invoices.first)
    end
  end
end
