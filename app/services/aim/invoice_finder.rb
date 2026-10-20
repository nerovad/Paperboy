# frozen_string_literal: true

module Aim
  # Find an invoice (#180): one stop for any invoice, wherever it is. Built
  # from the request's params:
  #
  # - q, the quick box: an AIM # ("AIM-118", "aim118") is that invoice; any
  #   other text is matched against the vendor (as typed or as the AI read
  #   it), the invoice # and the batch id, and against the total when it reads
  #   as an amount.
  # - where (a queue, or a Fiscal list -- the caller applies it), owner, budget
  #   unit and agency (as Search older invoices reads them), received between,
  #   manual entry, possible duplicate, and stale (Aim::Waiting).
  #
  # #invoices narrows an Aim::Invoice relation; #fetch returns at most CAP.
  class InvoiceFinder
    CAP = Aim::ArchiveSearch::CAP
    FIELDS = %i[q where owner budget_unit agency from to manual duplicate stale].freeze
    FLAGS = %i[manual duplicate stale].freeze
    HANDLE = /\AAIM-?(\d+)\z/i

    attr_reader :criteria, :problems

    def initialize(params)
      @criteria = FIELDS.to_h { |field| [field, params[field].to_s.squish] }.compact_blank
      FLAGS.each { |flag| @criteria.delete(flag) unless @criteria[flag] == '1' }
      @problems = []
      @from = read_date(:from)
      @to = read_date(:to)
      @units = Aim::ArchiveSearch.new(params.respond_to?(:slice) ? params.slice(:budget_unit, :agency) : {})
    end

    def searching? = criteria.any?

    def capped? = @capped

    def stale? = criteria.key?(:stale)

    # The AIM # typed in the quick box, if that is what it is.
    def handle_id = criteria[:q].to_s[HANDLE, 1]&.to_i

    def invoices(scope)
      scope = quick(scope, criteria[:q]) if criteria[:q]
      scope = scope.where(Aim::Invoice.arel_table[:assigned_to].matches("%#{Aim::Invoice.sanitize_sql_like(criteria[:owner])}%")) if criteria[:owner]
      scope = @units.invoices(scope)
      scope = scope.where(created_at: @from.beginning_of_day..) if @from
      scope = scope.where(created_at: ...@to.next_day.beginning_of_day) if @to
      scope = scope.where(manual_entry: true) if criteria[:manual]
      scope = scope.where(review_reason: 'duplicate').where.not(duplicate_of_id: nil) if criteria[:duplicate]
      scope = scope.where(state: Aim::Invoice::STATES - Aim::Invoice::TERMINAL_STATES) if stale?
      scope
    end

    # At most CAP rows of +scope+, newest first; with stale, only those
    # waiting Aim::Waiting.stale_days or more. +invoice+ maps a row to its
    # invoice (a Fiscal record's, say). #capped? says whether there were more.
    def fetch(scope, invoice: :itself.to_proc)
      rows = stale? ? stale_only(scope.to_a, invoice) : scope.limit(CAP + 1).to_a
      @capped = rows.size > CAP
      rows.first(CAP)
    end

    private

    def quick(scope, text)
      id = handle_id
      return scope.where(id: id) if id

      table = Aim::Invoice.arel_table
      pattern = "%#{Aim::Invoice.sanitize_sql_like(text)}%"
      match = %i[vendor_name extracted_vendor_name invoice_number batch_id].map { |column| table[column].matches(pattern) }.reduce(:or)
      amount = Aim::MoneyAttributes.parse(text) if text.match?(/\d/)
      match = match.or(table[:invoice_total].eq(amount)) if amount.is_a?(BigDecimal)
      scope.where(match)
    end

    def stale_only(rows, invoice)
      since = Aim::Waiting.since(rows.map(&invoice))
      rows.select { |row| (started = since[invoice.call(row).id]) && Aim::Waiting.days(started) >= Aim::Waiting.stale_days }
    end

    def read_date(field)
      return if criteria[field].blank?

      Date.iso8601(criteria[field])
    rescue Date::Error
      @problems << "#{criteria[field]} is not a date"
      nil
    end
  end
end
