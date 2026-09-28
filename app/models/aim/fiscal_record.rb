# frozen_string_literal: true

module Aim
  # What Fiscal records about an approved invoice (item f, demo first cut,
  # 2026-09-28). Kept beside the invoice, so the worker's states are untouched.
  #
  # review  -> Fiscal is filling it in (check number, pay doc, coding)
  # on_hold -> waiting on something, with a reason
  # ready   -> in the Report Queue, waiting for the report
  # exported, then archived: the report has gone to the payment software.
  #
  # Tags are Fiscal's own free text (Joshua, 2026-09-28), with DocuShare's
  # common ones offered as suggestions; they go in the report's Keywords.
  #
  # Every move is a line in the invoice's history (action 'fiscal').
  class FiscalRecord < Record
    STATUSES = %w[review on_hold ready exported archived].freeze
    STATUS_LABELS = { 'review' => 'Fiscal Queue', 'on_hold' => 'On Hold', 'ready' => 'Report Queue',
                      'exported' => 'Exported', 'archived' => 'Archived' }.freeze
    TRANSITIONS = {
      'review' => %w[on_hold ready],
      'on_hold' => %w[review ready],
      'ready' => %w[review on_hold exported],
      'exported' => %w[archived],
      'archived' => []
    }.freeze
    # Offered as you type a tag; anything else may be typed too. The marks
    # Fiscal put on DocuShare titles.
    TAG_SUGGESTIONS = ['#INV', '#BDO$', '#CT$', '#RQS', 'CT-PEND', 'HOLD PMT', 'DISCOUNT', 'Cross-FY Invoice',
                       '#INV_TAX CREDIT_DO NOT PAY', '#INV_TAX ERROR'].freeze
    # The states in which an invoice has been approved and belongs to Fiscal.
    APPROVED_STATES = %w[approved exporting exported].freeze
    FIELDS = %w[tags hold_reason bdo_do pay_doc_number check_number check_date credit_amount split_amount remit_to
                fund department org_number object_code dept_object activity function_code major_program program
                phase task description].freeze
    # The invoice's own fields Fiscal may correct on the Fiscal page.
    INVOICE_FIELDS = %w[vendor_name invoice_number invoice_date invoice_total subtotal sales_tax order_number
                        customer_number budget_unit document_type].freeze
    # What the Fiscal page lets Fiscal type; the hold reason is set by Hold.
    EDITABLE_FIELDS = (FIELDS - %w[hold_reason]).freeze

    belongs_to :invoice, class_name: 'Aim::Invoice'

    validates :status, inclusion: { in: STATUSES }
    validates :invoice_id, uniqueness: true

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

    # The name an approved invoice goes by, as Fiscal has always named them:
    # <BU>_<vendor>_<invoice no>_<yyyymmdd>. The report's Title, and the PDF's
    # file name once approved.
    def title = self.class.title_for(invoice)

    def self.title_for(invoice)
      [invoice.budget_unit, invoice.vendor_name, invoice.invoice_number, invoice.invoice_date&.strftime('%Y%m%d')]
        .map { |part| part.to_s.squish }.join('_')
    end

    # The title as a file name: characters Windows refuses become spaces.
    def self.file_name_for(invoice) = "#{title_for(invoice).tr('\\/:*?"<>|', ' ').squish}.pdf"

    def tag_list = tags.to_s.split(',').map(&:strip).compact_blank

    private

    def refusal(new_status)
      "This invoice is #{STATUS_LABELS[status]}; it cannot go to #{STATUS_LABELS[new_status] || new_status}."
    end
  end
end
