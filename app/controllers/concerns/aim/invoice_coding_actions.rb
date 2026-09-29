# frozen_string_literal: true

module Aim
  # The review page's coding buttons (item b.2): Look up coding again, and
  # the check Approve makes. Picking a rule fills the fields on the page
  # (aim_coding_choice_controller) and Save Changes keeps them. Needs @invoice and @queue;
  # named in Aim::InvoiceActions::ACTIONS.
  module InvoiceCodingActions
    extend ActiveSupport::Concern

    private

    # The lookup once more, from scratch: after a vendor or BU change, say.
    def relookup
      @invoice.coding_lines.destroy_all
      @invoice.update_column(:coded_at, nil)
      rules = Aim::CodingLookup.run!(@invoice)
      note = if rules.nil? then 'No coding rule matches now.'
             elsif rules.one? && @invoice.coding then 'Coded from the matching rule.'
             else "#{rules.size} rules match; pick one below."
             end
      redirect_to aim_invoice_path(@invoice.batch_id, queue: @queue), notice: "Looked up again. #{note}"
    end

    # Rules match but nobody has chosen, and nothing was typed.
    def coding_unpicked?
      @invoice.coding.nil? && Aim::CodingLookup.candidates(@invoice).present?
    end
  end
end
