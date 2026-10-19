# frozen_string_literal: true

module Aim
  # The finished lists (#169): Finished, Rejected and Deleted, and Fiscal's
  # Archived. They show what finished recently, the last 30 days unless the
  # person picks another window; anything older is found by Search older
  # invoices -- every finished invoice, on the server, by vendor, invoice #,
  # amount, budget unit, agency and when it finished. Nothing moves: older
  # invoices are only out of view. (Fiscal's Archived list is a step of
  # Fiscal's, "paid"; it is not what this searches.)
  #
  # Built from the request's params. #invoices narrows an Aim::Invoice
  # relation by the invoice's own fields; #window narrows any relation by the
  # column saying when it finished; #fetch returns at most CAP rows.
  class ArchiveSearch
    WINDOWS = [7, 30, 90, 365].freeze
    DEFAULT_WINDOW = 30
    CAP = 500
    FIELDS = %i[vendor invoice_number amount budget_unit agency from to].freeze
    # The finished queues of AIM staff, and Fiscal's finished list. Fiscal's
    # Exported is not one: each invoice there still waits for Fiscal to
    # archive it once paid, so an old one must stay in view.
    QUEUES = %w[exported rejected deleted].freeze
    FISCAL_STATUSES = { 'archived' => :archived_at }.freeze

    attr_reader :days, :criteria, :problems

    def initialize(params)
      @criteria = FIELDS.to_h { |field| [field, params[field].to_s.squish] }.compact_blank
      @days = WINDOWS.include?(params[:days].to_i) ? params[:days].to_i : DEFAULT_WINDOW
      @problems = []
      @amount = read_amount
      @from = read_date(:from)
      @to = read_date(:to)
    end

    # Searching older invoices, rather than showing the recent window.
    def searching? = criteria.any?

    def capped? = @capped

    # The invoice's own fields.
    def invoices(scope)
      scope = like(scope, %w[vendor_name extracted_vendor_name], criteria[:vendor])
      scope = like(scope, %w[invoice_number], criteria[:invoice_number])
      scope = scope.where(invoice_total: @amount) if @amount
      scope = scope.where(budget_unit: criteria[:budget_unit]) if criteria[:budget_unit]
      scope = in_agency(scope, criteria[:agency]) if criteria[:agency]
      scope
    end

    # When it finished: the dates searched, all time when searching without
    # them, otherwise the recent window. +column+ is an Arel attribute. A row
    # with no finish date (one the worker finished before #169 reached it) is
    # dated by its last change.
    def window(scope, column, fallback)
      from = @from&.beginning_of_day || (days.days.ago.beginning_of_day unless searching?)
      upto = @to&.next_day&.beginning_of_day
      scope = scope.where(dated(column, fallback) { |date| date.gteq(from) }) if from
      scope = scope.where(dated(column, fallback) { |date| date.lt(upto) }) if upto
      scope
    end

    # At most CAP rows; #capped? says whether there were more.
    def fetch(scope)
      rows = scope.limit(CAP + 1).to_a
      @capped = rows.size > CAP
      rows.first(CAP)
    end

    # "in the last 30 days", "from all time", "finished from March 1, 2026 to March 31, 2026".
    def describe
      return "in the last #{days} days" unless searching?
      return 'from all time' unless @from || @to

      ['finished', ("from #{@from.strftime('%B %-d, %Y')}" if @from), ("to #{@to.strftime('%B %-d, %Y')}" if @to)].compact.join(' ')
    end

    # What an empty list says.
    def nothing = searching? ? 'Nothing finished matches that search.' : "Nothing here #{describe}."

    private

    def dated(column, fallback)
      yield(column).or(column.eq(nil).and(yield(fallback)))
    end

    def like(scope, columns, text)
      return scope if text.blank?

      pattern = "%#{Aim::Invoice.sanitize_sql_like(text)}%"
      table = Aim::Invoice.arel_table
      scope.where(columns.map { |column| table[column].matches(pattern) }.reduce(:or))
    end

    # As Managing reads an agency: its stored agency, or for an invoice with
    # none yet, its budget unit's.
    def in_agency(scope, agency)
      units = Aim::Units.new.units_of(agency)
      scope.where(agency: agency).or(scope.where(agency: nil, budget_unit: units))
    end

    def read_amount
      return if criteria[:amount].blank?

      amount = Aim::MoneyAttributes.parse(criteria[:amount])
      return amount unless amount == :invalid

      @problems << "#{criteria[:amount]} is not an amount"
      nil
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
