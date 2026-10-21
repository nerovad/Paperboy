# frozen_string_literal: true

module Aim
  # How long invoices have been waiting, on two clocks (#190):
  #
  # * age -- since the invoice arrived (a split piece: since the PDF it was
  #   split from arrived). Nothing resets it, so it decides what is stale: an
  #   invoice handed from queue to queue every few days still turns red.
  # * here -- since it last reached its state or changed hands (#170), or
  #   since it arrived when its history says neither. How long the person or
  #   queue holding it now has had it.
  #
  # The age pills, the dashboards and the Stale panel read both. Finished
  # invoices are not waiting and are left out.
  module Waiting
    DEFAULT_STALE_DAYS = 30

    module_function

    # { invoice id => Time it arrived }, in one query.
    def arrived(invoices)
      list = invoices.to_a.reject(&:terminal?)
      parents = Aim::Invoice.where(id: list.filter_map(&:parent_id).uniq).pluck(:id, :created_at).to_h
      list.to_h { |invoice| [invoice.id, parents[invoice.parent_id] || invoice.created_at] }
    end

    # { invoice id => Time it started waiting where it is }, in two queries.
    def since(invoices)
      list = invoices.to_a.reject(&:terminal?)
      return {} if list.empty?

      ids = list.map(&:id)
      reached = Aim::InvoiceEvent.where(invoice_id: ids, to_state: list.map(&:state).uniq)
                                 .group(:invoice_id, :to_state).maximum(:created_at)
      handed = Aim::InvoiceEvent.where(invoice_id: ids, action: 'assignment').group(:invoice_id).maximum(:created_at)
      list.to_h { |invoice| [invoice.id, [reached[[invoice.id, invoice.state]], handed[invoice.id]].compact.max || invoice.created_at] }
    end

    def days(started, now: Time.current) = ((now - started) / 1.day).floor

    # An invoice this many days old or more is stale: the pill turns red and
    # the dashboard lists it. AIM_STALE_DAYS, a whole number of days, else 30.
    def stale_days
      days = ENV.fetch('AIM_STALE_DAYS', '').to_i
      days.positive? ? days : DEFAULT_STALE_DAYS
    end

    def stale?(arrived, now: Time.current) = days(arrived, now: now) >= stale_days
  end
end
