# frozen_string_literal: true

module Aim
  # What Fiscal records about an approved invoice (item f, demo first cut,
  # 2026-09-28). Kept beside the invoice, so the worker's states are untouched.
  #
  # review  -> Fiscal is filling it in (check number, pay doc, coding)
  # on_hold -> waiting on something, with a reason and a tag
  # ready   -> complete, waiting for the export
  # exported, then archived: the data has gone to the payment software.
  #
  # Every move is a line in the invoice's history (action 'fiscal').
  class FiscalRecord < Record
    STATUSES = %w[review on_hold ready exported archived].freeze
    STATUS_LABELS = { 'review' => 'Fiscal Queue', 'on_hold' => 'On Hold', 'ready' => 'Ready to Export',
                      'exported' => 'Exported', 'archived' => 'Archived' }.freeze
    TRANSITIONS = {
      'review' => %w[on_hold ready],
      'on_hold' => %w[review ready],
      'ready' => %w[review on_hold exported],
      'exported' => %w[archived],
      'archived' => []
    }.freeze
    # DocuShare's title and keyword tags: what holds an invoice, or marks it.
    TAGS = ['#INV', '#BDO$', '#CT$', '#INV_TAX CREDIT_DO NOT PAY', '#INV_TAX ERROR', '#RQS', 'DISCOUNT',
            'HOLD PMT', 'Cross-FY Invoice'].freeze
    DEFAULT_TAG = '#INV'
    # The states in which an invoice has been approved and belongs to Fiscal.
    APPROVED_STATES = %w[approved exporting exported].freeze
    FIELDS = %w[tag hold_reason bdo_do pay_doc_number check_number check_date credit_amount split_amount
                object_code dept_object activity function_code program phase task description].freeze
    # What the Fiscal page lets Fiscal type; the hold reason is set by Hold.
    EDITABLE_FIELDS = (FIELDS - %w[hold_reason]).freeze

    belongs_to :invoice, class_name: 'Aim::Invoice'

    validates :status, inclusion: { in: STATUSES }
    validates :invoice_id, uniqueness: true
    validates :tag, inclusion: { in: TAGS }, allow_blank: true

    scope :in_status, ->(status) { includes(:invoice).where(status: status) }

    # Every approved invoice has a record; new approvals get one here. Returns
    # how many were created.
    def self.take_in_approved!
      have = pluck(:invoice_id).to_set
      ids = Aim::Invoice.where(state: APPROVED_STATES).pluck(:id).reject { |id| have.include?(id) }
      ids.each { |id| create!(invoice_id: id) }
      ids.size
    end

    # { 'fiscal_review' => 3, ... }: the sidebar's counts, keyed as it is.
    def self.status_counts
      by_status = group(:status).count
      STATUSES.to_h { |status| ["fiscal_#{status}", by_status.fetch(status, 0)] }
    end

    def can_move_to?(new_status) = TRANSITIONS.fetch(status, []).include?(new_status.to_s)

    # Moves the record on, naming who moved it, and writes the history line.
    def move_to!(new_status, actor:, note: nil, **changes)
      new_status = new_status.to_s
      raise ArgumentError, refusal(new_status) unless can_move_to?(new_status)

      transaction do
        old = status
        update!(changes.merge(status: new_status, updated_by: actor))
        invoice.events.create!(action: 'fiscal', actor: actor,
                               note: ["Fiscal: #{STATUS_LABELS[old]} → #{STATUS_LABELS[new_status]}", note].compact.join(' — '))
      end
    end

    def status_label = STATUS_LABELS.fetch(status, status.to_s.humanize)

    # DocuShare's title: <tag>_<BU>_<vendor>_<invoice no>_<yyyymmdd>.
    def title
      [tag.presence || DEFAULT_TAG, invoice.budget_unit, invoice.vendor_name, invoice.invoice_number,
       invoice.invoice_date&.strftime('%Y%m%d')].join('_')
    end

    private

    def refusal(new_status)
      "This invoice is #{STATUS_LABELS[status]}; it cannot go to #{STATUS_LABELS[new_status] || new_status}."
    end
  end
end
