# frozen_string_literal: true

module Aim
  # What the dashboards show beyond the queue counts (#131): what needs
  # attention, today's movement, the oldest waiting, and each agency group's
  # share -- for the groups picked in Managing (+invoices+ is their scope).
  class DashboardStats
    WEEK = 7.days

    Tile = Data.define(:key, :label, :count, :path, :tone, :hint)

    attr_reader :invoices

    def initialize(invoices, now: Time.current, groups: Aim::AgencyGroups.new)
      @invoices = invoices
      @now = now
      @groups = groups
    end

    # The pipeline's "needs attention" row.
    def pipeline_tiles(routes)
      ready = invoices.where(state: 'ready_for_approval')
      [
        Tile.new(key: 'duplicate', label: 'Possible duplicates', tone: 'danger', hint: 'AIM staff decide each one',
                 count: invoices.where(state: 'needs_review', review_reason: 'duplicate').count,
                 path: routes.aim_invoices_path(queue: 'needs_review', reason: 'duplicate')),
        Tile.new(key: 'manual', label: 'Manual data entry', tone: 'warning', hint: 'typed in by hand, not by the AI',
                 count: ready.where(manual_entry: true).count, path: routes.aim_invoices_path(queue: 'ready_for_approval')),
        Tile.new(key: 'second', label: 'Awaiting second approval', tone: 'info', hint: 'over their BU\'s amount',
                 count: ready.where.not(first_approved_by: nil).count, path: routes.aim_invoices_path(queue: 'ready_for_approval')),
        Tile.new(key: 'stale', label: 'Over a week old', tone: 'warning', hint: 'in Ready for Approval',
                 count: aged(ready, WEEK).size, path: routes.aim_invoices_path(queue: 'ready_for_approval')),
        Tile.new(key: 'failed', label: 'Failed', tone: 'danger', hint: 'open one to see why',
                 count: invoices.where(state: 'failed').count, path: routes.aim_invoices_path(queue: 'failed'))
      ]
    end

    # Someone's own row: +invoices+ are the ones they own.
    def personal_tiles(routes)
      ready = invoices.where(state: 'ready_for_approval')
      [
        Tile.new(key: 'queue', label: 'In my queue', tone: 'info', hint: 'ready for my approval',
                 count: ready.count, path: routes.aim_my_queue_path),
        Tile.new(key: 'stale', label: 'Over a week old', tone: 'warning', hint: 'the oldest are below',
                 count: aged(ready, WEEK).size, path: routes.aim_my_queue_path),
        Tile.new(key: 'second', label: 'My second approvals', tone: 'info', hint: 'high-dollar, first approval given',
                 count: ready.where.not(first_approved_by: nil).count, path: routes.aim_my_queue_path),
        Tile.new(key: 'manual', label: 'To type in', tone: 'warning', hint: 'Manual Data Entry Needed',
                 count: ready.where(manual_entry: true).count, path: routes.aim_my_queue_path)
      ]
    end

    # Fiscal's "needs attention" row, over Fiscal records of these invoices.
    def fiscal_tiles(routes)
      records = Aim::FiscalRecord.served_by(invoices)
      [
        Tile.new(key: 'manual', label: 'Need data entry', tone: 'warning', hint: 'uploaded straight to Fiscal',
                 count: records.where(status: 'review').joins(:invoice).where(invoice: { manual_entry: true }).count,
                 path: routes.aim_fiscal_path(status: 'review')),
        Tile.new(key: 'hold', label: 'On hold over a week', tone: 'danger', hint: 'still waiting on something',
                 count: records.where(status: 'on_hold').where(updated_at: ...(@now - WEEK)).count,
                 path: routes.aim_fiscal_path(status: 'on_hold')),
        Tile.new(key: 'report', label: 'Ready to report', tone: 'info', hint: 'in the Report Queue',
                 count: records.where(status: 'ready').count, path: routes.aim_fiscal_path(status: 'ready')),
        Tile.new(key: 'archive', label: 'Exported over 30 days', tone: 'warning', hint: 'archive once paid',
                 count: records.where(status: 'exported').where(exported_at: ...(@now - 30.days)).count,
                 path: routes.aim_fiscal_path(status: 'exported'))
      ]
    end

    # { 'arrived' => n, 'approved' => n, 'rejected' => n, 'exported' => n } since midnight.
    def today
      ids = invoices.select(:id)
      events = Aim::InvoiceEvent.where(invoice_id: ids, created_at: @now.beginning_of_day..)
      {
        'arrived' => invoices.where(created_at: @now.beginning_of_day..).count,
        'approved' => events.where(to_state: 'approved').distinct.count(:invoice_id),
        'rejected' => events.where(to_state: 'rejected').distinct.count(:invoice_id),
        'exported' => events.where(to_state: 'exported').distinct.count(:invoice_id)
      }
    end

    # The +limit+ oldest in +state+: [[invoice, days old, days here], ...]
    # (Aim::Waiting's two clocks, #190).
    def oldest(state, limit: 5)
      list = aged(invoices.where(state: state), 0.seconds).sort_by { |_, seconds| -seconds }.first(limit)
      here = Aim::Waiting.since(list.map(&:first))
      list.map { |invoice, seconds| [invoice, (seconds / 1.day).floor, Aim::Waiting.days(here.fetch(invoice.id, invoice.created_at), now: @now)] }
    end

    # Invoices in any active queue +days+ old or more (#170, by age since
    # #190), by queue then whoever holds them now: [[queue, owner, count,
    # oldest days], ...], oldest first. Never finished ones: nothing here is
    # purged or moved, only shown.
    def stale(days: Aim::Waiting.stale_days)
      aged(invoices.where(state: Aim::Invoice::STATES - Aim::Invoice::TERMINAL_STATES), days.days)
        .group_by { |invoice, _| [invoice.queue, invoice.queue_owner] }
        .map { |(queue, owner), rows| [queue, owner, rows.size, (rows.map(&:last).max / 1.day).floor] }
        .sort_by { |row| -row.last }
    end

    # { group => { label => count } }: invoices in +columns+' states
    # ({ label => [state, ...] }), by agency group. Work in progress only.
    def by_group(columns)
      states = columns.values.flatten.uniq
      tally(invoices.where(state: states).to_a) { |invoice| columns.select { |_, list| list.include?(invoice.state) }.keys }
    end

    # The same for Fiscal: { group => { status => count } }.
    def fiscal_by_group(statuses)
      records = Aim::FiscalRecord.served_by(invoices).where(status: statuses).includes(:invoice).to_a
      tally(records.map(&:invoice).zip(records.map(&:status))) { |_, status| [status] }
    end

    private

    # Counts +items+ (invoices, or [invoice, x] pairs) by agency group and the
    # columns the block names for each.
    def tally(items)
      out = Hash.new { |hash, group| hash[group] = Hash.new(0) }
      items.each do |item|
        invoice = item.is_a?(Array) ? item.first : item
        group = @groups.for_invoice(invoice)
        yield(item).each { |column| out[group][column] += 1 } if group
      end
      out.sort_by { |group, _| group.name }.to_h
    end

    # [[invoice, seconds old], ...] since it arrived (Aim::Waiting.arrived),
    # at least +at_least+. Age, not time with its holder, so handing an
    # invoice on does not make it young again.
    def aged(scope, at_least)
      list = scope.to_a
      arrived = Aim::Waiting.arrived(list)
      list.filter_map do |invoice|
        seconds = @now - arrived.fetch(invoice.id, invoice.created_at)
        [invoice, seconds] if seconds >= at_least
      end
    end
  end
end
