# frozen_string_literal: true

module Aim
  # Who may look at an invoice and who may work it.
  #
  # Looking: AIM staff see every invoice; a BU Admin every invoice in their
  # BUs; anyone else the invoices in their own queue that are ready for them.
  #
  # Working: in Ready for Approval, the owner works their own invoice and AIM
  # staff work the shared queue's; someone else's is read only, with a Claim
  # button for staff that moves it to their queue. Before that -- Action
  # Needed, Needs Split, Failed -- AIM staff work any invoice. Whoever works
  # an invoice holds its working lock while their page is open, and anyone
  # else opening it meanwhile reads it only.
  module InvoiceAccess
    extend ActiveSupport::Concern

    OWNER_ACTIONS = ['Save Changes', 'Approve', 'Send Back', 'Reject'].freeze
    # What a BU Admin may do to someone else's invoice in their BUs: look,
    # move and claim -- never approve it (decided 2026-09-25).
    BU_ADMIN_ACTIONS = %w[show pdf reassign claim].freeze

    private

    def staff? = helpers.aim_queue_access?

    def mine? = @invoice.assigned_employee_id.present? && @invoice.assigned_employee_id == current_user_employee_id

    # In the shared queue of a BU you cover.
    def shared_to_me?
      return false unless @invoice.assigned_employee_id.nil?

      units = Aim::Users.shared_budget_units(current_user_employee_id, staff: staff?)
      units.nil? || units.include?(@invoice.budget_unit)
    end

    # The invoice is in a BU this person is BU Admin of.
    def bu_admin_here?
      units = helpers.aim_bu_admin_units
      units.present? && units.include?(@invoice.budget_unit)
    end

    def editor?
      return false if @invoice.terminal?
      return mine? || shared_to_me? if @invoice.state == 'ready_for_approval'

      staff?
    end

    # A ready invoice that is not yours may be claimed from a shared queue you
    # cover, or by AIM staff from anyone's.
    def claimable?
      @invoice.state == 'ready_for_approval' && !mine? && (staff? || shared_to_me? || bu_admin_here?)
    end

    def require_staff_or_owner
      return if staff?
      return if bu_admin_here? && BU_ADMIN_ACTIONS.include?(action_name)
      return deny_owner unless @invoice.state == 'ready_for_approval' && (mine? || shared_to_me?)
      return if action_name != 'update' || OWNER_ACTIONS.include?(params[:commit].to_s)

      deny_owner
    end

    # Changing the invoice needs the right to work it, and nobody else in it.
    def require_editor
      return if editor? && !@invoice.claimed_by_other?(current_user_email)

      message = if @invoice.claimed_by_other?(current_user_email)
                  "#{helpers.aim_claimant_label(@invoice)} is working on this invoice, so it is read only."
                else
                  'This invoice is not yours to change. Claim it first.'
                end
      redirect_to aim_invoice_path(@invoice.batch_id, queue: @queue), alert: message
    end

    # A queue belongs to someone who works AIM; nobody else has one.
    def outsider?(owner)
      !@invoice.terminal? && owner != Aim::Invoice::SHARED_QUEUE && !Aim::Users.member?(owner)
    end

    def refuse_outsider
      redirect_back_or_to home_queue_path, alert: 'That person does not work AIM, so they have no queue.'
    end

    def home_queue_path = queue_return_path

    def deny_owner
      redirect_to aim_my_queue_path, alert: 'That invoice is not in your queue.'
    end
  end
end
