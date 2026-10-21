# frozen_string_literal: true

module Aim
  # What a stamp can say (#221): every field Fiscal may put in a stamp area's
  # text as {name} or {name|format}, its label in the designer, the format it
  # takes when none is given, and a sample for the designer's preview.
  #
  # #values reads them for one invoice: its own columns, its approval history,
  # its first coding line, and its Fiscal record.
  module StampFields
    DATE = '%m/%d/%Y'
    STAMP_TIME = '%m/%d/%Y_%H:%M:%S'

    FIELDS = {
      'received' => { label: 'Date received', group: 'Approval', format: DATE, sample: Date.new(2025, 6, 24) },
      'invoice_date' => { label: 'Invoice date', group: 'Approval', format: DATE, sample: Date.new(2025, 6, 16) },
      'approver' => { label: 'Approved by', group: 'Approval', sample: 'Martinez, Mark' },
      'approver_initials' => { label: 'Approver initials', group: 'Approval', sample: 'MM' },
      'approved_at' => { label: 'Approved at', group: 'Approval', format: STAMP_TIME,
                         sample: Time.zone.local(2025, 6, 27, 12, 27, 3) },
      'first_approver' => { label: 'First approval by (high dollar)', group: 'Approval', sample: 'Lee, Sam' },
      'first_approved_at' => { label: 'First approval at', group: 'Approval', format: STAMP_TIME,
                               sample: Time.zone.local(2025, 6, 26, 9, 5, 0) },
      'vendor' => { label: 'Vendor', group: 'Invoice', sample: 'Iron Mountain' },
      'invoice_number' => { label: 'Invoice #', group: 'Invoice', sample: 'KRWD768' },
      'total' => { label: 'Total', group: 'Invoice', sample: BigDecimal('1234.50') },
      'subtotal' => { label: 'Subtotal', group: 'Invoice', sample: BigDecimal('1150.00') },
      'sales_tax' => { label: 'Sales tax', group: 'Invoice', sample: BigDecimal('84.50') },
      'budget_unit' => { label: 'Budget unit', group: 'Invoice', sample: '4641' },
      'document_type' => { label: 'Document type', group: 'Invoice', sample: 'Invoice' },
      'order_number' => { label: 'Order #', group: 'Invoice', sample: 'PO-1237418' },
      'customer_number' => { label: 'Customer #', group: 'Invoice', sample: 'C-00177434' },
      'batch_id' => { label: 'Batch id', group: 'Invoice', sample: '4641.20251021_085405.Invoice-[2YVB]' },
      'encumbrance' => { label: 'BDO / DO', group: 'Coding', sample: 'BDO_26000123' },
      'object_code' => { label: 'Account (object)', group: 'Coding', sample: '2051' },
      'fund' => { label: 'Fund', group: 'Coding', sample: '1000' },
      'department' => { label: 'Department', group: 'Coding', sample: '4640' },
      'program' => { label: 'Program', group: 'Coding', sample: '100' },
      'activity' => { label: 'Activity', group: 'Coding', sample: '0001' },
      'vendor_code' => { label: 'Vendor code', group: 'Coding', sample: 'VC0001234' },
      'check_number' => { label: 'Check #', group: 'Fiscal', sample: '004512' },
      'check_date' => { label: 'Check date', group: 'Fiscal', format: DATE, sample: Date.new(2025, 7, 3) },
      'pay_doc_number' => { label: 'Pay doc #', group: 'Fiscal', sample: 'PV-2025-0712' },
      'stamped_on' => { label: 'Date stamped', group: 'Fiscal', format: DATE, sample: Date.new(2025, 6, 27) }
    }.freeze

    # The designer's worst case: every field at its longest. Text fields take
    # the longest value they have ever had in AIM (WORST_SOURCES), or the
    # stand-in here when that is longer -- so a new install, or a field
    # nobody has filled yet, is still stretched. Money is a large credit;
    # dates fall in September, the widest month.
    WORST = {
      'approver' => 'Montgomery-Fitzgerald, Alexandria Catherine', 'approver_initials' => 'AMF',
      'first_approver' => 'Vasquez-Delacroix, Maximiliano Sebastian',
      'vendor' => 'Consolidated Environmental Engineering & Laboratory Services of Southern California, Inc.',
      'invoice_number' => 'INV-2026-0000123456-REV-03', 'document_type' => 'Statement', 'budget_unit' => '46410',
      'order_number' => 'PO-2026-00001237418-CHG-02', 'customer_number' => 'CUST-0000177434-00982',
      'batch_id' => '4641.20260930_235959.Consolidated Environmental Engineering Invoice 0000123456-[ZZ9Z]',
      'encumbrance' => 'BDO_2026-000123456', 'object_code' => '2051-0000', 'fund' => '1000-0000', 'department' => '4640-0000',
      'program' => '100-00000', 'activity' => '0001-0000', 'vendor_code' => 'VC000123456789',
      'check_number' => '0000045120', 'pay_doc_number' => 'PV-2026-0000712345'
    }.freeze

    # Where each text field's longest real value is found: [model, column].
    WORST_SOURCES = {
      'vendor' => [Aim::Invoice, :vendor_name], 'invoice_number' => [Aim::Invoice, :invoice_number],
      'batch_id' => [Aim::Invoice, :batch_id], 'order_number' => [Aim::Invoice, :order_number],
      'customer_number' => [Aim::Invoice, :customer_number], 'document_type' => [Aim::Invoice, :document_type],
      'object_code' => [Aim::CodingLine, :object_code], 'fund' => [Aim::CodingLine, :fund],
      'department' => [Aim::CodingLine, :department], 'program' => [Aim::CodingLine, :program],
      'activity' => [Aim::CodingLine, :activity], 'vendor_code' => [Aim::CodingLine, :vendor_code],
      'check_number' => [Aim::FiscalRecord, :check_number], 'pay_doc_number' => [Aim::FiscalRecord, :pay_doc_number]
    }.freeze

    module_function

    def formats = FIELDS.transform_values { |field| field[:format] }.compact

    def samples = FIELDS.transform_values { |field| field[:sample] }

    def known?(name) = FIELDS.key?(name.to_s)

    # { field => value } for +invoice+, as it is now. +record+ is its Fiscal
    # record when it has one.
    def values(invoice, record = Aim::FiscalRecord.find_by(invoice_id: invoice.id))
      approval = approvals(invoice)
      coding = invoice.coding
      {
        'received' => invoice.created_at&.in_time_zone, 'invoice_date' => invoice.invoice_date,
        'approver' => approval[:name], 'approver_initials' => initials(approval[:name]), 'approved_at' => approval[:at],
        'first_approver' => first_approver(invoice), 'first_approved_at' => invoice.first_approved_at&.in_time_zone,
        'vendor' => invoice.vendor_name, 'invoice_number' => invoice.invoice_number, 'total' => invoice.invoice_total,
        'subtotal' => invoice.subtotal, 'sales_tax' => invoice.sales_tax, 'budget_unit' => invoice.budget_unit,
        'document_type' => invoice.document_type, 'order_number' => invoice.order_number,
        'customer_number' => invoice.customer_number, 'batch_id' => invoice.batch_id,
        'encumbrance' => coding&.encumbrance, 'object_code' => coding&.object_code, 'fund' => coding&.fund,
        'department' => coding&.department, 'program' => coding&.program, 'activity' => coding&.activity,
        'vendor_code' => coding&.vendor_code,
        'check_number' => record&.check_number, 'check_date' => record&.check_date,
        'pay_doc_number' => record&.pay_doc_number, 'stamped_on' => Time.zone.today
      }
    end

    # Every field at its longest (WORST, WORST_SOURCES), for the designer.
    def worst_case
      worst = samples.merge(WORST)
      WORST_SOURCES.each do |field, (model, column)|
        longest = longest_value(model, column)
        worst[field] = longest if longest && longest.length > worst[field].to_s.length
      end
      longest_name = longest_approver
      worst['approver'] = longest_name if longest_name && longest_name.length > worst['approver'].length
      worst.merge('total' => BigDecimal('-9999999.99'), 'subtotal' => BigDecimal('-9999999.99'),
                  'sales_tax' => BigDecimal('-999999.99'), 'received' => Date.new(2026, 9, 28),
                  'invoice_date' => Date.new(2026, 9, 28), 'check_date' => Date.new(2026, 9, 28),
                  'stamped_on' => Date.new(2026, 9, 28), 'approved_at' => Time.zone.local(2026, 9, 28, 23, 58, 59),
                  'first_approved_at' => Time.zone.local(2026, 9, 28, 23, 58, 59))
    end

    def longest_value(model, column)
      model.where.not(column => [nil, '']).order(Arel.sql("LEN(#{model.connection.quote_column_name(column)}) DESC"))
           .limit(1).pluck(column).first
    rescue ActiveRecord::ActiveRecordError
      nil
    end

    # The longest "Last, First" among the people who work AIM.
    def longest_approver
      Employee.where(id: Aim::Member.select(:employee_id)).pluck(:first_name, :last_name)
              .map { |first, last| Employee.format_sort_name(first, last) }.max_by(&:length)
    rescue ActiveRecord::ActiveRecordError
      nil
    end

    # The last approval: who, as "Last, First", and when.
    def approvals(invoice)
      event = invoice.events.where(to_state: 'approved').reorder(:created_at, :id).last
      return {} unless event

      name = Aim::FiscalExport.approver_names([event.actor]).fetch(event.actor.to_s.downcase, event.actor)
      { name: name, at: event.created_at.in_time_zone }
    end

    def first_approver(invoice)
      email = invoice.first_approved_by.presence or return
      Aim::FiscalExport.approver_names([email]).fetch(email.downcase, email)
    end

    # "Martinez, Mark" -> "MM"; an email or one word -> its first letters.
    def initials(name)
      return if name.blank?

      last, first = name.to_s.split(',', 2).map(&:strip)
      parts = first ? [first, last] : name.to_s.split(/[\s@.]+/)
      parts.compact_blank.map { |part| part[0].upcase }.join.presence
    end
  end
end
