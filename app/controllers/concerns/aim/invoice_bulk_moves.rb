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

      unit, refusal = unit_for(owner)
      return redirect_back_or_to(home_queue_path, alert: refusal) if refusal

      moved = @invoice.reassign!(owner, actor: current_user_email, unit: unit, exception: keeping_unit?(owner))
      notice = moved ? "Moved to #{helpers.aim_owner_label(@invoice.queue_owner)}." : 'The invoice was already there.'
      redirect_back_or_to home_queue_path, notice: notice
    rescue Aim::Invoice::IllegalTransition, ActiveRecord::RecordInvalid => e
      redirect_back_or_to home_queue_path, alert: e.message
    end

    def reassign_many
      return move_many_to_other_unit if params[:destination] == 'other_unit'

      owner = params[:destination] == 'shared' ? Aim::Invoice::SHARED_QUEUE : params[:owner]
      return redirect_back_or_to(aim_my_queue_path, alert: 'That person is not in AIM, so they have no queue.') if owner != Aim::Invoice::SHARED_QUEUE && !Aim::Users.member?(owner)

      moved, skipped = move_each(Array(params[:ids]).map(&:to_s).uniq) do |invoice|
        unit, refusal = unit_for(owner)
        raise Aim::Invoice::IllegalTransition, refusal if refusal

        invoice.reassign!(owner, actor: current_user_email, unit: unit, exception: keeping_unit?(owner))
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

    # The BU follows the person (Joshua, 2026-09-29): an invoice goes to
    # someone who works in its budget unit; otherwise it takes one of theirs
    # (new_budget_unit), or -- this invoice only -- an AIM Admin or its BU
    # Admin keeps it in its own (keep_unit). Returns [new unit or nil, refusal
    # or nil].
    def unit_for(owner)
      return [nil, nil] if owner == Aim::Invoice::SHARED_QUEUE || @invoice.terminal?

      bu = @invoice.budget_unit
      theirs = Aim::Users.budget_units_of(owner)
      return [nil, nil] if bu.blank? || theirs.include?(bu)
      return [nil, nil] if keeping_unit?(owner)
      return [nil, "Only an AIM Admin or #{bu}'s BU Admin can keep it in #{bu} for someone outside it."] if params[:keep_unit] == '1'

      unit = params[:new_budget_unit].to_s.strip
      return [unit, nil] if theirs.include?(unit) && unit_allowed?(unit)

      name = Aim::Invoice.employee_name(owner) || 'That person'
      [nil, "#{name} does not work in #{bu}. Pick one of their budget units for it, or ask an AIM Admin or #{bu}'s BU Admin " \
            "to add them to #{bu}."]
    end

    def keeping_unit?(owner)
      params[:keep_unit] == '1' && owner != Aim::Invoice::SHARED_QUEUE && (staff? || bu_admin_here?) &&
        !Aim::Users.budget_units_of(owner).include?(@invoice.budget_unit)
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
