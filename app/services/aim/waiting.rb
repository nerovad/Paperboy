# frozen_string_literal: true

module Aim
  # How long invoices have waited where they are (#170): since each last
  # reached its state or changed hands, or since it arrived when its history
  # says neither. The dashboards' "waiting" and the queues' age pills read it.
  # Finished invoices are not waiting and are left out.
  module Waiting
    DEFAULT_STALE_DAYS = 30

    module_function

    # { invoice id => Time it started waiting }, in two queries.
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

    # Waiting this many days or more is stale: the pill turns red and the
    # dashboard lists it. AIM_STALE_DAYS, a whole number of days, else 30.
    def stale_days
      days = ENV.fetch('AIM_STALE_DAYS', '').to_i
      days.positive? ? days : DEFAULT_STALE_DAYS
    end
  end
end
