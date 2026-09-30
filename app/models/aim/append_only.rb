# frozen_string_literal: true

module Aim
  # A row written once and never changed: once persisted it is read-only, so
  # it can be neither edited nor deleted. AIM's history tables
  # (Aim::InvoiceEvent, Aim::CodingRuleChange).
  module AppendOnly
    extend ActiveSupport::Concern

    def readonly? = persisted? || super
  end
end
