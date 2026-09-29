# frozen_string_literal: true

module Aim
  # The review page's coding (item b.2): the Coding box's data, Look up
  # coding again (public: an action), forgetting a rule-made line when the
  # match keys change, and the check Approve makes. Picking a rule fills the fields on the page
  # (aim_coding_choice_controller) and Save Changes keeps them. Needs @invoice and @queue;
  # named in Aim::InvoiceActions::ACTIONS.
  module InvoiceCodingActions
    extend ActiveSupport::Concern

    included do
      public :relookup
    end

    # The coding rules once more, from scratch, and the Coding box drawn
    # again for the page to swap in (aim_coding_choice_controller#relookup).
    def relookup
      @invoice.coding_lines.destroy_all
      @invoice.update_column(:coded_at, nil)
      rules = Aim::CodingLookup.run!(@invoice)
      @coding_notice = if rules.nil? then 'Looked up again: no coding rule matches now.'
                       elsif rules.one? && @invoice.coding then 'Looked up again and coded from the matching rule.'
                       else "Looked up again: #{rules.size} rules match; tick one."
                       end
      @read_only = false
      prepare_coding
      render partial: 'aim/invoices/coding', layout: false
    end

    private

    # The invoice's coding, or the rules to choose from (item b.2). The
    # fields are always there, with the COA's lists, for a person to type.
    def prepare_coding
      Aim::CodingLookup.ensure!(@invoice)
      @coding_lines = @invoice.coding_lines.to_a
      @coding_line = @invoice.coding || @invoice.coding_lines.build(line_no: 1)
      @coa = Aim::CoaCodes.new(@invoice.agency!.to_s)
      return if @coding_lines.any? || !@invoice.coded?

      @coding_level, @coding_candidates = Aim::CodingLookup.candidates(@invoice)
      return if @coding_candidates.blank?

      @coding_differing = Aim::CodingLookup.differing_fields(@coding_candidates)
      @coding_hinted = Aim::CodingLookup.hinted(@coding_candidates, stored_pdf_path)
    end

    # A new vendor, BU or customer number may match other rules.
    def forget_coding_if_rematch_needed
      changed = @invoice.previous_changes.keys & %w[vendor_name budget_unit customer_number]
      return if changed.empty?

      @invoice.update_column(:agency, nil) if changed.include?('budget_unit')
      @invoice.forget_rule_coding!
    end

    # Rules match but nobody has chosen, and nothing was typed.
    def coding_unpicked?
      @invoice.coding.nil? && Aim::CodingLookup.candidates(@invoice).present?
    end
  end
end
