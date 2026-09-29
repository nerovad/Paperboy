# frozen_string_literal: true

module Aim
  # Loads a lookup file as coding rules (item b): reads it (Aim::LookupFile),
  # checks every code against the COA (Aim::CoaCodes), and reports what it
  # would load and what it refuses, row by row, before anything is written.
  # `apply!` then writes the rules as one Aim::CodingImport: a row already in
  # effect with the same coding is skipped; one with different coding is
  # retired the day before the new rule starts, so the file replaces what it
  # covers and leaves the rest.
  #
  # Two kinds of refusal. A row with no vendor or no budget unit cannot be a
  # rule and stays refused. A row the COA objects to may be accepted anyway
  # (`accept: :all`, or the row numbers) -- there are always exceptions
  # (Joshua, 2026-09-28) -- and the rule then carries the objection as its
  # warnings, in sight on the screen.
  class LookupImport
    REQUIRED = %w[vendor_name budget_unit].freeze
    Outcome = Struct.new(:row, :rule, :reasons, :objections, :notes, :accepted, keyword_init: true) do
      def refused? = reasons.any? || (objections.any? && !accepted)
      def acceptable? = reasons.empty? && objections.any?
    end

    attr_reader :agency, :file_name, :outcomes, :effective_option, :effective_date

    # budget_unit: the BU for rows that name none (Facilities' file has no
    # column for it).
    def initialize(path, agency:, effective: 'bdo', effective_date: nil, budget_unit: nil, accept: :none)
      @path = path
      @file_name = File.basename(path)
      @agency = agency.to_s.upcase
      @effective_option = effective
      @effective_date = effective_date
      @default_unit = budget_unit.presence
      @accept = accept
      @coa = Aim::CoaCodes.new(@agency)
      @file = Aim::LookupFile.new(path)
      @outcomes = @file.rows.map { |row| judge(row) }
    end

    def loadable = outcomes.reject(&:refused?)
    def refused = outcomes.select(&:refused?)

    # add / edit / unchanged / refused, against the rules standing now.
    def outcome_kind(outcome)
      return 'refused' if outcome.refused?

      standing = standing_rules(outcome.rule, nil, outcome.row.fields['rule_id'].presence&.to_i)
      return 'add' if standing.empty?

      standing.any? { |s| s.same_as?(outcome.rule) && s.vendor_key == outcome.rule.vendor_key } ? 'unchanged' : 'edit'
    end

    def report = Aim::LookupReport.build(self)

    def unknown_columns = @file.unknown_columns

    def apply!(by:, import: nil)
      raise ArgumentError, "#{agency} is not an agency in the chart of accounts" unless @coa.agency?

      Aim::CodingRule.transaction do
        import ||= Aim::CodingImport.new(agency: agency, file_name: file_name, effective_option: effective_option,
                                         effective_from: effective_date)
        import.update!(imported_by: by, row_count: outcomes.size, refused_count: refused.size, status: 'applied')
        loaded = 0
        retired = 0
        loadable.each do |outcome|
          rule = outcome.rule
          rule.assign_attributes(import_id: import.id, source_row: outcome.row.number, created_by: by)
          same, different = standing_rules(rule, import, outcome.row.fields['rule_id'].presence&.to_i)
                            .partition { |standing| standing.same_as?(rule) && standing.vendor_key == rule.vendor_key }
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
      objections = []
      objections << 'no coding and no encumbrance' if (Aim::CodingRule::CODING_FIELDS + %w[encumbrance_type]).none? { |f| values[f].present? }
      bad = @coa.invalid_fields(values.slice(*Aim::CoaCodes::LISTS.keys))
      # Sheriff writes its department as the agency code (SHF); noted, not refused.
      row.notes << "department #{values['department'].inspect} is not in the COA" if bad.delete('department')
      objections += bad.map { |field| "#{field.humanize.downcase} #{values[field].inspect} is not in the COA for #{agency}" }
      accepted = reasons.empty? && objections.any? && accepted?(row.number)
      attributes = values.slice(*Aim::CodingRule::FIELDS).merge(agency: agency, warnings: (objections.join('; ') if accepted))
      rule = Aim::CodingRule.new(attributes.merge(effective_from: effective_from_for(values, row.notes)))
      rule.vendor_key = Aim::CodingRule.key_for(rule.vendor_name)
      Outcome.new(row: row, rule: rule, reasons: reasons, objections: objections, notes: row.notes, accepted: accepted)
    end

    def accepted?(row_number)
      @accept == :all || (@accept.respond_to?(:include?) && @accept.include?(row_number))
    end

    # bdo: the date in the encumbrance number (BDO_4700 2024 07 29 ...; CT_4620
    # FY23 ...), else today, and noted. today / date: as asked.
    def effective_from_for(values, notes)
      case effective_option
      when 'date' then effective_date || Date.current
      when 'today' then Date.current
      else
        date = Aim::LookupFile.date_in(values['encumbrance_number'])
        notes << 'no date in the encumbrance number; effective today' if date.nil?
        date || Date.current
      end
    end

    # The rules this one replaces: the same vendor and customer in the BU, and
    # the rule a downloaded row names by id (so a re-upload edits it, a renamed
    # vendor included). Never one from the same file: a vendor listed several
    # times there (4703's BDO lines) is several choices. Rules made by hand
    # have no import, and count.
    def standing_rules(rule, import, rule_id = nil)
      scope = Aim::CodingRule.in_effect(rule.effective_from).for_agency(agency)
      scope = scope.where('import_id IS NULL OR import_id <> ?', import.id) if import
      same_key = scope.where(budget_unit: rule.budget_unit, vendor_key: rule.vendor_key, customer_number: rule.customer_number.presence)
      rule_id ? (same_key.to_a | scope.where(id: rule_id).to_a) : same_key.to_a
    end
  end
end
