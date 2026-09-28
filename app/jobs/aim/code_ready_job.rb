# frozen_string_literal: true

module Aim
  # Codes the invoices a person could see that nobody has opened yet
  # (Aim::CodingLookup), every ten minutes (config/recurring.yml).
  class CodeReadyJob < ApplicationJob
    queue_as :default

    def perform
      Aim::Invoice.where(state: Aim::CodingLookup::STATES, coded_at: nil).find_each { |invoice| Aim::CodingLookup.run!(invoice) }
    end
  end
end
