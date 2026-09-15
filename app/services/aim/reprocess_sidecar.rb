# frozen_string_literal: true

module Aim
  # The metadata file that travels with an invoice into the reprocess queue.
  #
  # The reprocess queue is the one queue with no job ticket: Rails' retry action
  # and the batch splitter both put work there, and neither is the watcher. The
  # AI worker reads a sidecar named after the PDF beside it and takes `bu` and
  # `submitter` from it — so without one it falls back to BU "Unknown" and the
  # retried invoice loses the Budget Unit it was filed under. Plan step 3.2.
  class ReprocessSidecar
    # Each queue writes the Budget Unit under whichever name its own metadata
    # uses: the SQL payload says BU, a job ticket says bu_number, and the
    # Laserfiche XML says Budget Unit Number. The worker reads exactly one
    # name, so they are resolved here rather than at each call site.
    BU_KEYS = ['BU', 'bu', 'bu_number', 'BudgetUnit', 'Budget Unit Number'].freeze
    SUBMITTER_KEYS = ['Submitter', 'submitter', 'submitter_name', 'Submitted by'].freeze

    def self.for(metadata)
      new(metadata).to_h
    end

    def initialize(metadata)
      @metadata = metadata || {}
    end

    # The whole metadata comes along — the worker reads three keys but a
    # reviewer opening the folder should still see what was extracted.
    # `error` is dropped: read_metadata reports an unreadable file that way,
    # and it is a symptom of this read, not a field of the invoice.
    def to_h
      sidecar = @metadata.except('error')

      # Absent rather than empty: the worker falls back to "Unknown" on a
      # missing key, and a guessed Budget Unit is worse than no Budget Unit.
      sidecar['bu'] = budget_unit if budget_unit
      sidecar['submitter'] = submitter if submitter
      sidecar
    end

    private

    def budget_unit = first_value(BU_KEYS)
    def submitter = first_value(SUBMITTER_KEYS)

    def first_value(keys)
      keys.filter_map { |key| @metadata[key].presence }.first
    end
  end
end
