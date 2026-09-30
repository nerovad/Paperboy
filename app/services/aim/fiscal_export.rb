# frozen_string_literal: true

require 'csv'

module Aim
  # Fiscal's report (item f): one CSV, the header row and one row per invoice,
  # for the macro that feeds the payment software. The header is exactly the
  # one Fiscal's macro was built on: these 30 columns, in this order (Joshua,
  # 2026-09-28, corrected the same day: no Org_Number, no trailing space on
  # Handle). Nothing of DocuShare's own blocks, and no DocuShare format: AIM
  # replaces it.
  class FiscalExport
    COLUMNS = [
      'Title', 'Invoice Number', 'Vendor Name', 'Customer Number', 'Order Number', 'Invoice Date AP',
      'Create Date', 'Modified Date', 'Expiration Date', 'Past Due', 'Sales Tax', 'SubTotal', 'Credit Amount',
      'Total', 'Keywords', 'BDO / DO', 'Pay Doc Number', 'Description', 'Unit', 'Object', 'Dept Object',
      'Activity', 'Function', 'Program', 'Phase', 'Task', 'Split Invoice Amount', 'Handle', 'Archive Date',
      'Check Number'
    ].freeze

    # Numbers Fiscal's macro reads as numbers. A credit is negative, so these
    # start with "-" and must reach the macro as written; every other cell is
    # text and is defused against formula injection (Paperboy::CsvSafe).
    MONEY_COLUMNS = ['Sales Tax', 'SubTotal', 'Credit Amount', 'Total', 'Split Invoice Amount'].freeze
    MONEY_INDEXES = MONEY_COLUMNS.to_set { |name| COLUMNS.index(name) }.freeze

    attr_reader :records

    def initialize(records)
      @records = records.to_a
      @stamps = self.class.approval_stamps(@records.map(&:invoice_id))
    end

    # "Last, First_mm/dd/yyyy_hh:mm:ss" per invoice id: who approved it and
    # when, as the approval stamp and the report's Description carry it. The
    # history names the approver by email; GSABSS turns that into a name.
    def self.approval_stamps(invoice_ids)
      approvals = Aim::InvoiceEvent.where(invoice_id: invoice_ids, to_state: 'approved').order(:created_at, :id)
                                   .pluck(:invoice_id, :actor, :created_at).index_by(&:first)
      names = approver_names(approvals.values.map { |row| row[1] })
      approvals.transform_values do |_, actor, at|
        "#{names.fetch(actor.to_s.downcase, actor)}_#{at.in_time_zone.strftime('%m/%d/%Y_%H:%M:%S')}"
      end
    end

    def self.approver_names(emails)
      Employee.where(email: emails.compact.uniq).pluck(:email, :last_name, :first_name)
              .to_h { |email, last, first| [email.to_s.downcase, Employee.format_sort_name(first, last)] }
    rescue ActiveRecord::ActiveRecordError
      {}
    end

    def filename = "AIM_Fiscal_Report_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"

    def rows = records.map { |record| defused(row(record)) }

    def to_csv
      CSV.generate { |csv| ([COLUMNS] + rows).each { |line| csv << line } }
    end

    private

    # The coding comes from the invoice's coding line (item b.2). Split
    # Invoice Amount is filled only when there is more than one line.
    def row(record)
      invoice = record.invoice
      line = invoice.coding || Aim::CodingLine.new
      split = invoice.coding_lines.size > 1 ? money(line.amount) : nil
      [
        record.title, invoice.invoice_number, invoice.vendor_name, invoice.customer_number, invoice.order_number,
        invoice.invoice_date&.strftime('%Y%m%d'), day(invoice.created_at), day(record.updated_at), nil, nil,
        money(invoice.sales_tax), money(invoice.subtotal), money(record.credit_amount), money(invoice.invoice_total),
        record.tag_list.join(', '), line.encumbrance, record.pay_doc_number, description(record), invoice.budget_unit,
        line.object_code, line.dept_object, line.activity, line.function_code, line.program, line.phase, line.task,
        split, invoice.handle, day(record.archived_at), record.check_number
      ]
    end

    # As Fiscal's own reports have it: the approval stamp's text, then " _ "
    # and whatever Fiscal wrote.
    def description(record)
      [@stamps[record.invoice_id], record.description.presence].compact.join(' _ ')
    end

    def defused(cells)
      cells.each_with_index.map { |cell, index| MONEY_INDEXES.include?(index) ? cell : Paperboy::CsvSafe.defuse_cell(cell) }
    end

    def day(value) = value&.in_time_zone&.strftime('%m/%d/%Y')

    def money(value) = value.nil? ? nil : format('%.2f', value)
  end
end
