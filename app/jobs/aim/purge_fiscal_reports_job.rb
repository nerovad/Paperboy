# frozen_string_literal: true

module Aim
  # Purges the files of Fiscal reports a year old (#131), every night
  # (config/recurring.yml). The report's number, its invoices and their
  # history lines stay.
  class PurgeFiscalReportsJob < ApplicationJob
    queue_as :default

    def perform
      Aim::FiscalReport.expired.find_each(&:purge!)
    end
  end
end
