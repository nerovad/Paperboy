# frozen_string_literal: true

module Aim
  # Loads a lookup file as coding rules (item b): reads it (Aim::LookupFile),
  # checks every code against the COA (Aim::CoaCodes), and reports what it
  # would load and what it refuses, row by row, before anything is written.
  # `apply!` then writes the rules as one Aim::CodingImport: a row already in
  # effect with the same coding is skipped; one with different coding is
  # retired the day before the new rule starts, so the file replaces what it
  # covers and leaves the rest.
  class LookupImport
    REQUIRED = %w[vendor_name budget_unit].freeze
    Outcome = Struct.new(:row, :rule, :reasons, :notes, keyword_init: true) do
      def refused? = reasons.any?
    end

    attr_reader :agency, :file_name, :outcomes, :effective_option, :effective_date

    # budget_unit: the BU for rows that name none (Facilities' file has no
    # column for it).
    def initialize(path, agency:, effective: 'bdo', effective_date: nil, budget_unit: nil)
      @path = path
      @file_name = File.basename(path)
      @agency = agency.to_s.upcase
      @effective_option = effective
      @effective_date = effective_date
      @default_unit = budget_unit.presence
      @coa = Aim::CoaCodes.new(@agency)
      @file = Aim::LookupFile.new(path)
      @outcomes = @file.rows.map { |row| judge(row) }
    end

    def loadable = outcomes.reject(&:refused?)
    def refused = outcomes.select(&:refused?)

    def report
      { file: file_name, agency: agency, rows: outcomes.size, loadable: loadable.size, refused: refused.size,
        unknown_columns: @file.unknown_columns,
        refused_rows: refused.map { |o| { row: o.row.number, vendor: o.row.fields['vendor_name'], reasons: o.reasons } },
        noted_rows: loadable.select { |o| o.notes.any? }.map { |o| { row: o.row.number, notes: o.notes } } }
    end

    def apply!(by:)
      raise ArgumentError, "#{agency} is not an agency in the chart of accounts" unless @coa.agency?

      Aim::CodingRule.transaction do
        import = Aim::CodingImport.create!(agency: agency, file_name: file_name, imported_by: by,
                                           effective_option: effective_option, effective_from: effective_date,
                                           row_count: outcomes.size, refused_count: refused.size)
        loaded = 0
        retired = 0
        loadable.each do |outcome|
          rule = outcome.rule
          rule.assign_attributes(import_id: import.id, source_row: outcome.row.number, created_by: by)
          same, different = standing_rules(rule).partition { |standing| standing.same_as?(rule) }
          next if same.any?

          different.each { |standing| standing.retire!(on: rule.effective_from - 1, by: by, import_id: import.id) }
          retired += different.size
          rule.record_change('created', nil, nil, "row #{outcome.row.number} of #{file_name}", by)
          rule.save!
          loaded += 1
        end
        import.update!(loaded_count: loaded, retired_count: retired, report: report)
        import
      end
    end

    private

    def judge(row)
      values = row.fields
      if values['budget_unit'].blank? && @default_unit
        values['budget_unit'] = @default_unit
        row.notes << "budget unit #{@default_unit} given at import"
      end
      reasons = REQUIRED.reject { |field| values[field].present? }.map { |field| "no #{field.humanize.downcase}" }
      reasons << 'no coding and no encumbrance' if (Aim::CodingRule::CODING_FIELDS + %w[encumbrance_type]).none? { |f| values[f].present? }
      bad = @coa.invalid_fields(values.slice(*Aim::CoaCodes::LISTS.keys))
      # Sheriff writes its department as the agency code (SHF); noted, not refused.
      row.notes << "department #{values['department'].inspect} is not in the COA" if bad.delete('department')
      reasons += bad.map { |field| "#{field.humanize.downcase} #{values[field].inspect} is not in the COA for #{agency}" }
      attributes = values.slice(*Aim::CodingRule::FIELDS)
      rule = Aim::CodingRule.new(attributes.merge(agency: agency, effective_from: effective_from_for(values, row.notes)))
      Outcome.new(row: row, rule: rule, reasons: reasons, notes: row.notes)
    end

    # bdo: the date in the encumbrance number (BDO_4700 2024 07 29 ...; CT_4620
    # FY23 ...), else today, and noted. today / date: as asked.
    def effective_from_for(values, notes)
      case effective_option
      when 'date' then effective_date || Date.current
      when 'today' then Date.current
      else
        date = date_in(values['encumbrance_number'])
        notes << 'no date in the encumbrance number; effective today' if date.nil?
        date || Date.current
      end
    end

    def date_in(number)
      digits = number.to_s.sub(/\A\d{4}/, '')
      if (m = digits.match(/\A(20\d{2})(\d{2})(\d{2})/))
        Date.new(m[1].to_i, m[2].to_i, m[3].to_i)
      elsif (m = digits.match(/\AFY(\d{2})/i))
        Date.new(2000 + m[1].to_i - 1, 7, 1)
      end
    rescue Date::Error
      nil
    end

    def standing_rules(rule)
      Aim::CodingRule.in_effect(rule.effective_from).for_agency(agency)
                     .where(budget_unit: rule.budget_unit, vendor_key: Aim::CodingRule.key_for(rule.vendor_name))
                     .where(customer_number: rule.customer_number.presence).to_a
    end
  end
end
