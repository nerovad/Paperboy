# frozen_string_literal: true

module Aim
  # The check Approve makes on the coding (item b.2). Picking a rule fills the fields on the page
  # (aim_coding_choice_controller) and Save Changes keeps them. Needs @invoice and @queue;
  # named in Aim::InvoiceActions::ACTIONS.
  module InvoiceCodingActions
    extend ActiveSupport::Concern

    private

    # Rules match but nobody has chosen, and nothing was typed.
    def coding_unpicked?
      @invoice.coding.nil? && Aim::CodingLookup.candidates(@invoice).present?
    end
  end
end
