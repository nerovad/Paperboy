# frozen_string_literal: true

require 'csv'

module Aim
  # Fiscal's bulk export (item f demo): the header row and one row per invoice,
  # in DocuShare's column order. Two formats until Fiscal says which their
  # macro takes: DocuShare's own (tab-separated, UTF-16 with a byte order mark,
  # every value quoted) and plain CSV. DocuShare's "Class Name", Collection and
  # SavedQuery blocks are its own, not data, and are left out (Joshua).
  class FiscalExport
    COLUMNS = [
      'Title', 'Invoice Number', 'Vendor Name', 'Customer Number', 'Order Number', 'Invoice Date AP',
      'Create Date', 'Modified Date', 'Expiration Date', 'Past Due', 'Sales Tax', 'SubTotal', 'Credit Amount',
      'Total', 'Keywords', 'BDO / DO', 'Pay Doc Number', 'Description', 'Unit', 'Object', 'Dept Object',
      'Activity', 'Function', 'Program', 'Phase', 'Task', 'Split Invoice Amount', 'Handle', 'Archive Date',
      'Check Number'
    ].freeze
    BOM = "\uFEFF"
    FORMATS = { 'docushare' => 'DocuShare (tab-separated, UTF-16)', 'csv' => 'CSV' }.freeze

    attr_reader :records

    def initialize(records)
      @records = records.to_a
      @stamps = self.class.approval_stamps(@records.map(&:invoice_id))
    end

    # "Last, First_mm/dd/yyyy_hh:mm:ss" per invoice id: who approved it and
    # when, as the approval stamp and DocuShare's Description carry it. The
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
              .to_h { |email, last, first| [email.to_s.downcase, "#{last}, #{first}"] }
    rescue ActiveRecord::ActiveRecordError
      {}
    end

    def filename(format)
      "aim_fiscal_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.#{format == 'csv' ? 'csv' : 'txt'}"
    end

    def content_type(format) = format == 'csv' ? 'text/csv' : 'text/tab-separated-values; charset=utf-16le'

    def render(format) = format == 'csv' ? to_csv : to_docushare

    def rows = records.map { |record| row(record) }

    def to_csv
      CSV.generate { |csv| ([COLUMNS] + rows).each { |line| csv << line } }
    end

    # UTF-16LE with its byte order mark, tabs between values, every value in
    # double quotes (a quote inside one doubled), CRLF line ends: DocuShare's.
    def to_docushare
      text = ([COLUMNS] + rows).map { |line| line.map { |value| %("#{value.to_s.gsub('"', '""')}") }.join("\t") }
                               .join("\r\n")
      "#{BOM}#{text}\r\n".encode('UTF-16LE')
    end

    private

    def row(record)
      invoice = record.invoice
      [
        record.title, invoice.invoice_number, invoice.vendor_name, invoice.customer_number, invoice.order_number,
        invoice.invoice_date&.strftime('%Y%m%d'), day(invoice.created_at), day(record.updated_at), nil, nil,
        money(invoice.sales_tax), money(invoice.subtotal), money(record.credit_amount), money(invoice.invoice_total),
        record.tag.presence || FiscalRecord::DEFAULT_TAG, record.bdo_do, record.pay_doc_number, description(record),
        invoice.budget_unit, record.object_code, record.dept_object, record.activity, record.function_code,
        record.program, record.phase, record.task, record.split_amount, invoice.batch_id, day(record.archived_at),
        record.check_number
      ]
    end

    # What Fiscal typed, else the hold reason while held, else the approval
    # stamp's text.
    def description(record)
      return record.description if record.description.present?
      return record.hold_reason if record.status == 'on_hold' && record.hold_reason.present?

      @stamps[record.invoice_id]
    end

    def day(value) = value&.in_time_zone&.strftime('%m/%d/%Y')

    def money(value) = value.nil? ? nil : format('%.2f', value)
  end
end
