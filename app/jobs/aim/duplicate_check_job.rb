# frozen_string_literal: true

module Aim
  # Flags possible duplicates for AIM staff (#131, Aim::InvoiceDuplicates),
  # every minute (config/recurring.yml).
  class DuplicateCheckJob < ApplicationJob
    queue_as :default

    def perform
      Aim::Invoice.check_duplicates!
    end
  end
end
