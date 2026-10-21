# frozen_string_literal: true

module Aim
  # The stamp designer's worst case (#221): every field of Aim::StampFields
  # at its longest, so a layout can be tried against the worst it will meet.
  module StampWorstCase
    # Text fields take the longest value they have ever had in AIM
    # (WORST_SOURCES), or the stand-in here when that is longer -- so a new
    # install, or a field nobody has filled yet, is still stretched. Coding
    # fields take their longest real code (#worst_coding). Money is a large
    # credit; dates fall in September, the widest month.
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

    def call
      worst = Aim::StampFields.samples.merge(WORST)
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
      columns = Aim::StampFields::CODING - ['encumbrance']
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
  end
end
