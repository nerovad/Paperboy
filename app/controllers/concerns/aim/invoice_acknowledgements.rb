# frozen_string_literal: true

module Aim
  # Acknowledge rejected and deleted invoices (#169): one, or every ticked
  # one, leaves the Rejected or Deleted list for everyone, with a history line
  # each. AIM Admins only, and only invoices of the agency groups picked in
  # Managing, as the list shows them. A second click on one already
  # acknowledged does nothing.
  module InvoiceAcknowledgements
    extend ActiveSupport::Concern

    included do
      before_action :require_aim_admin, only: :acknowledge
    end

    def acknowledge
      ids = Array(params[:ids]).map(&:to_s).uniq
      invoices = helpers.aim_agency_groups.invoices(helpers.aim_managing_groups).where(batch_id: ids).to_a
      done = invoices.count { |invoice| invoice.acknowledge!(actor: current_user_email, name: current_user_name) }
      notice = done.zero? ? 'Nothing to acknowledge: those were already acknowledged.' : "Acknowledged #{helpers.pluralize(done, 'invoice')}."
      redirect_back_or_to aim_invoices_path(queue: @queue), notice: notice
    end
  end
end
