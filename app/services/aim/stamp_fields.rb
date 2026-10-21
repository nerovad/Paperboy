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

    # The coding fields, in the chart of accounts' order, labelled as the
    # Fiscal pages label them.
    CODING = (%w[encumbrance ma_number vendor_code] + Aim::CodingFields::COA_FIELDS).freeze

    # A coding line as a real rule reads, for an install with no coding rules
    # yet; otherwise the samples come from the fullest real rule
    # (#rule_sample).
    CODING_SAMPLE = {
      'encumbrance' => 'BDO_4640260001', 'vendor_code' => 'VC00014335', 'fund' => 'G001', 'department' => 'GSA',
      'object_code' => '2051', 'activity' => 'GATV', 'function_code' => 'GFUN', 'major_program' => 'INDR',
      'program' => 'INDIRECT'
    }.freeze

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
      **CODING.to_h do |field|
        [field, { label: Aim::FiscalHelper::CODING_FIELD_LABELS.fetch(field), group: 'Coding', sample: CODING_SAMPLE[field] }]
      end,
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
      'check_number' => '0000045120', 'pay_doc_number' => 'PV-2026-0000712345'
    }.freeze

    # Where each text field's longest real value is found: [model, column].
    WORST_SOURCES = {
      'vendor' => [Aim::Invoice, :vendor_name], 'invoice_number' => [Aim::Invoice, :invoice_number],
      'batch_id' => [Aim::Invoice, :batch_id], 'order_number' => [Aim::Invoice, :order_number],
      'customer_number' => [Aim::Invoice, :customer_number], 'document_type' => [Aim::Invoice, :document_type],
      'check_number' => [Aim::FiscalRecord, :check_number], 'pay_doc_number' => [Aim::FiscalRecord, :pay_doc_number]
    }.freeze

    module_function

    def formats = FIELDS.transform_values { |field| field[:format] }.compact

    DEFAULT_AGENCY = 'GSA'

    # Typical values: the fixed samples, with the coding, vendor and budget
    # unit of +agency+'s fullest real coding rule (GSA's unless another is
    # given), so the designer shows codes as they really read, each in its
    # own field.
    def samples(agency: nil) = FIELDS.transform_values { |field| field[:sample] }.merge(rule_sample(agency.presence || DEFAULT_AGENCY))

    # +agency+'s coding rule with the most coding fields filled (any agency's
    # when it has none), as stamp values.
    def rule_sample(agency)
      scored = CODING - ['encumbrance'] + ['encumbrance_number']
      recent = Aim::CodingRule.order(id: :desc).limit(2000)
      rules = recent.where(agency: agency).to_a.presence || recent.to_a
      rule = rules.max_by { |row| scored.count { |field| sample_worthy?(row, field) } }
      return {} unless rule

      CODING.to_h { |field| [field, rule.public_send(field).presence] }
            .merge('vendor' => rule.vendor_name, 'budget_unit' => rule.budget_unit, 'customer_number' => rule.customer_number)
            .compact
    rescue ActiveRecord::ActiveRecordError
      {}
    end

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
        **CODING.to_h { |field| [field, coding&.public_send(field)] },
        'check_number' => record&.check_number, 'check_date' => record&.check_date,
        'pay_doc_number' => record&.pay_doc_number, 'stamped_on' => Time.zone.today
      }
    end

    # A vendor code counts only when it is one (VC and digits); some lookups
    # carry account notes in that column.
    def sample_worthy?(row, field)
      value = row.public_send(field)
      field == 'vendor_code' ? value.to_s.match?(/\AVC\d+\z/) : value.present?
    end

    # An invoice's own values, with samples standing in for any still empty
    # (no approver yet, no coding): what the designer's "This invoice" fills
    # in, so a layout can be judged on an invoice that is not approved yet.
    def with_samples(invoice)
      samples(agency: invoice.agency).merge(values(invoice).reject { |_, value| value.blank? })
    end

    # Every field at its longest (WORST, WORST_SOURCES), for the designer.
    def worst_case
      worst = samples.merge(WORST)
      WORST_SOURCES.each do |field, (model, column)|
        longest = longest_value(model, column)
        worst[field] = longest if longest && longest.length > worst[field].to_s.length
      end
      worst.merge!(worst_coding)
      longest_name = longest_approver
      worst['approver'] = longest_name if longest_name && longest_name.length > worst['approver'].length
      worst.merge('total' => BigDecimal('-9999999.99'), 'subtotal' => BigDecimal('-9999999.99'),
                  'sales_tax' => BigDecimal('-999999.99'), 'received' => Date.new(2026, 9, 28),
                  'invoice_date' => Date.new(2026, 9, 28), 'check_date' => Date.new(2026, 9, 28),
                  'stamped_on' => Date.new(2026, 9, 28), 'approved_at' => Time.zone.local(2026, 9, 28, 23, 58, 59),
                  'first_approved_at' => Time.zone.local(2026, 9, 28, 23, 58, 59))
    end

    # Each coding field's longest real value, in the rules or on coding lines;
    # the sample where neither has one.
    def worst_coding
      columns = CODING - ['encumbrance']
      longest = columns.to_h do |field|
        [field, [Aim::CodingRule, Aim::CodingLine].filter_map { |model| longest_value(model, field) }.max_by(&:length)]
      end
      longest.merge('encumbrance' => longest_encumbrance).compact
    end

    def longest_encumbrance
      Aim::CodingRule.where.not(encumbrance_number: [nil, ''])
                     .order(Arel.sql("LEN(encumbrance_number) + LEN(ISNULL(encumbrance_type, '')) DESC")).first&.encumbrance
    rescue ActiveRecord::ActiveRecordError
      nil
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
