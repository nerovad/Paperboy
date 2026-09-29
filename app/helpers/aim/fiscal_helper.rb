# frozen_string_literal: true

module Aim
  # Labels and badges for the Fiscal stage (item f).
  module FiscalHelper
    FISCAL_FIELD_LABELS = {
      'tags' => 'Tags', 'hold_reason' => 'Hold Reason', 'pay_doc_number' => 'Pay Doc Number',
      'check_number' => 'Check Number', 'check_date' => 'Check Date', 'credit_amount' => 'Credit Amount',
      'description' => 'Description'
    }.freeze

    CODING_FIELD_LABELS = {
      'encumbrance' => 'BDO / DO', 'encumbrance_type' => 'Encumbrance Type', 'encumbrance_number' => 'Encumbrance Number',
      'ma_number' => 'MA Number', 'vendor_code' => 'Vendor Code', 'fund' => 'Fund', 'department' => 'Department',
      'org_number' => 'Org Number', 'object_code' => 'Object', 'dept_object' => 'Dept Object', 'activity' => 'Activity',
      'function_code' => 'Function', 'major_program' => 'Major Program', 'program' => 'Program', 'phase' => 'Phase',
      'task' => 'Task', 'amount' => 'Amount', 'customer_number' => 'Customer Number', 'budget_unit' => 'Budget Unit'
    }.freeze

    # A column heading on Coding Rules that sorts the list.
    def aim_rules_sort_link(label, sort)
      text = @sort == sort ? "#{label} ▾" : label
      link_to text, aim_coding_rules_path(agency: @agency, unit: @unit, show: @show, sort: sort), class: 'aim-sort-link'
    end

    def aim_coding_field_label(field) = CODING_FIELD_LABELS.fetch(field.to_s, field.to_s.humanize)

    FISCAL_DESCRIPTIONS = {
      'review' => 'Approved invoices to work.',
      'on_hold' => 'Waiting on something. Each says why.',
      'ready' => 'Tick invoices and download the report.',
      'exported' => 'In a report. Archive each once it is paid.',
      'archived' => 'Finished.'
    }.freeze

    FISCAL_BADGES = { 'review' => 'is-in-review', 'on_hold' => 'is-denied', 'ready' => 'is-pending',
                      'exported' => 'is-sent', 'archived' => 'is-approved' }.freeze

    def aim_fiscal_field_label(field) = FISCAL_FIELD_LABELS.fetch(field.to_s, field.to_s.humanize)

    def aim_fiscal_description(status) = FISCAL_DESCRIPTIONS[status.to_s]

    def aim_fiscal_badge(record)
      tag.span(record.status_label, class: "badge #{FISCAL_BADGES.fetch(record.status, 'is-pending')}")
    end

    # The Report Queue's are reported; exported ones can be downloaded again.
    def aim_fiscal_exportable?(status) = %w[ready exported].include?(status.to_s)
  end
end
