# frozen_string_literal: true

module Aim
  # One line of an invoice's history. Written once and never changed: a
  # persisted event is read-only, so it can be neither edited nor deleted.
  class InvoiceEvent < Record
    include Aim::AppendOnly

    belongs_to :invoice, class_name: 'Aim::Invoice'

    validates :action, :actor, presence: true
  end
end
