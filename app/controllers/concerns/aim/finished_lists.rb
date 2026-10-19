# frozen_string_literal: true

module Aim
  # The finished lists (#169) -- Finished, Rejected and Deleted, and Fiscal's
  # Exported and Archived -- show a recent window, or what the archive search
  # found, at most Aim::ArchiveSearch::CAP rows. The working lists show
  # everything in them. Sets @archive on a finished list, for the search bar.
  module FinishedLists
    extend ActiveSupport::Concern

    private

    # The queue list, given the invoices Managing serves in @queue.
    def finished_or_all(scope)
      return scope.to_a unless Aim::ArchiveSearch::QUEUES.include?(@queue)

      @archive = Aim::ArchiveSearch.new(params)
      invoices = Aim::Invoice.arel_table
      @archive.fetch(@archive.window(@archive.invoices(scope), invoices[:finished_at], invoices[:updated_at]))
    end

    # The Fiscal list for @status, newest invoice first.
    def finished_or_all_records
      records = Aim::FiscalRecord.in_status(@status).joins(:invoice)
                                 .order(Aim::Invoice.arel_table[:created_at].desc, Aim::FiscalRecord.arel_table[:id].desc)
      finished = Aim::ArchiveSearch::FISCAL_STATUSES[@status]
      return records.served_by(served_invoices).to_a unless finished

      @archive = Aim::ArchiveSearch.new(params)
      table = Aim::FiscalRecord.arel_table
      @archive.fetch(@archive.window(records.served_by(@archive.invoices(served_invoices)), table[finished], table[:updated_at]))
    end
  end
end
