# frozen_string_literal: true

module Aim
  # The Invoices tab on My Work and the invoice count on the name badge:
  # both shown to anyone with an AIM queue of their own. Asked once per page,
  # since the tab bar and the header both want it. These draw on every
  # Paperboy page, so anything going wrong in AIM hides them rather than
  # breaking a page that is not AIM's.
  module WorkTabHelper
    def aim_invoices_tab?
      return @aim_invoices_tab unless @aim_invoices_tab.nil?

      @aim_invoices_tab = current_user.present? && aim_has_queue?
    rescue StandardError => e
      Rails.logger.error "AIM could not decide on the Invoices tab: #{e.message}"
      @aim_invoices_tab = false
    end
  end
end
