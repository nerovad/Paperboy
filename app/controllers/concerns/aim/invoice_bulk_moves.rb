# frozen_string_literal: true

module Aim
  # Move several invoices at once, from the checkboxes on a queue. Each one is
  # checked on its own: an invoice you could not move with its own Move button
  # is skipped here too, and the message says how many.
  #
  # Also the move to another budget unit's shared queue, one invoice or many:
  # it changes the invoice's BU, so the BU has to be one the mover may send to
  # (Aim::AccessHelper#aim_move_units).
  module InvoiceBulkMoves
    extend ActiveSupport::Concern

    # Move an invoice to another person's queue, or to SHARED.
    def reassign
      return move_to_other_unit if params[:destination] == 'other_unit'

      owner = params[:destination] == 'shared' ? Aim::Invoice::SHARED_QUEUE : params[:owner]
      return refuse_outsider if outsider?(owner)
      return refuse_out_of_unit unless target_in_unit?(owner)

      moved = @invoice.reassign!(owner, actor: current_user_email)
      notice = moved ? "Moved to #{helpers.aim_owner_label(@invoice.queue_owner)}." : 'The invoice was already there.'
      redirect_back_or_to home_queue_path, notice: notice
    rescue Aim::Invoice::IllegalTransition, ActiveRecord::RecordInvalid => e
      redirect_back_or_to home_queue_path, alert: e.message
    end

    def reassign_many
      return move_many_to_other_unit if params[:destination] == 'other_unit'

      owner = params[:destination] == 'shared' ? Aim::Invoice::SHARED_QUEUE : params[:owner]
      if owner != Aim::Invoice::SHARED_QUEUE && !Aim::Users.member?(owner)
        return redirect_back_or_to(aim_my_queue_path, alert: 'That person does not work AIM, so they have no queue.')
      end

      moved, skipped = move_each(Array(params[:ids]).map(&:to_s).uniq) do |invoice|
        raise Aim::Invoice::IllegalTransition, 'outside the BU' unless target_in_unit?(owner)

        invoice.reassign!(owner, actor: current_user_email)
      end
      report_moves(moved, skipped)
    end

    private

    def move_to_other_unit
      unit = params[:budget_unit].to_s.strip
      return refuse_unit unless unit_allowed?(unit)
      return redirect_back_or_to(home_queue_path, alert: 'You cannot move this invoice.') unless movable_by_me?

      moved = @invoice.move_to_unit!(unit, actor: current_user_email)
      redirect_back_or_to home_queue_path, notice: moved ? "Moved to the #{unit} shared queue." : 'The invoice was already there.'
    rescue Aim::Invoice::IllegalTransition, ActiveRecord::RecordInvalid => e
      redirect_back_or_to home_queue_path, alert: e.message
    end

    def move_many_to_other_unit
      unit = params[:budget_unit].to_s.strip
      return refuse_unit unless unit_allowed?(unit)

      moved, skipped = move_each(Array(params[:ids]).map(&:to_s).uniq) { |invoice| invoice.move_to_unit!(unit, actor: current_user_email) }
      report_moves(moved, skipped)
    end

    # A BU Admin moving someone else's invoice keeps it inside the BU: the
    # person it goes to must cover the invoice's budget unit.
    def target_in_unit?(owner)
      return true if staff? || owner == Aim::Invoice::SHARED_QUEUE || mine? || shared_to_me?

      Aim::Users.shared_budget_units(owner, staff: false).include?(@invoice.budget_unit)
    end

    def refuse_out_of_unit
      redirect_back_or_to home_queue_path, alert: "That person does not cover #{@invoice.budget_unit}, so it cannot go to them."
    end

    def unit_allowed?(unit)
      allowed = helpers.aim_move_units
      unit.present? && (allowed.nil? || allowed.include?(unit))
    end

    def refuse_unit
      redirect_back_or_to aim_my_queue_path, alert: 'You cannot move invoices to that budget unit.'
    end

    # Yields each invoice the mover may move; the block moves it and returns
    # nil when it was already there, which counts as neither moved nor skipped.
    def move_each(batch_ids)
      moved = skipped = 0
      Aim::Invoice.where(batch_id: batch_ids).find_each do |invoice|
        @invoice = invoice
        next skipped += 1 unless movable_by_me?

        moved += 1 if yield(invoice)
      rescue Aim::Invoice::IllegalTransition, ActiveRecord::RecordInvalid
        skipped += 1
      end
      [moved, skipped]
    end

    def report_moves(moved, skipped)
      notice = "Moved #{helpers.pluralize(moved, 'invoice')}."
      notice += " #{helpers.pluralize(skipped, 'invoice')} could not be moved by you and were left." if skipped.positive?
      redirect_back_or_to aim_my_queue_path, notice: notice
    end

    # What the single Move allows: AIM Admins move any open invoice, a BU
    # Admin any in their BUs; anyone else their own ready invoices and those in
    # shared queues they cover.
    def movable_by_me?
      return false if @invoice.terminal?
      return true if staff? || bu_admin_here?

      @invoice.state == 'ready_for_approval' && (mine? || shared_to_me?)
    end
  end
end
