# frozen_string_literal: true

module Aim
  # The coding lookups (item b.3): the rules by agency and budget unit, one
  # rule to edit with the COA checking every code (Save anyway keeps the
  # objection as a warning), its history, and Retire. Fiscal and AIM Admins,
  # each in the BUs of their agency groups (#131).
  class CodingRulesController < BaseController
    before_action :require_fiscal
    before_action :set_rule, only: %i[show update retire]

    SORTS = { 'budget_unit' => %i[budget_unit vendor_key], 'vendor' => %i[vendor_key budget_unit],
              'encumbrance' => %i[encumbrance_number vendor_key], 'object' => %i[object_code vendor_key],
              'program' => %i[program vendor_key], 'fund' => %i[fund vendor_key],
              'effective' => %i[effective_from vendor_key] }.freeze

    def index
      @unit = params[:unit].presence
      @show = params[:show] == 'all' ? 'all' : 'in_effect'
      @sort = SORTS.key?(params[:sort]) ? params[:sort] : 'budget_unit'
      reading_database('list the coding rules', alert: 'The coding rules could not be read.',
                                                empty: { rules: [], agencies: [], units: [], units_without_rules: [] }) do
        @units = Aim::CodingRule.distinct.order(:budget_unit).pluck(:agency, :budget_unit)
                                .select { |agency, unit| managed_unit?(agency, unit) }
        @agencies = @units.map(&:first).uniq.sort
        @agency = @agencies.include?(params[:agency]) ? params[:agency] : @agencies.first
        if request.format.csv?
          @rules = managed(filtered_rules.order(*SORTS[@sort], :id))
          return send_data(export_csv, filename: "AIM_Coding_Rules_#{@agency}.csv", type: 'text/csv')
        end

        # Every rule of the agency groups picked in Managing goes to the page;
        # agency, BU and in-effect filter there, as you choose them
        # (aim_queue_filter_controller facets).
        @rules = managed(Aim::CodingRule.order(*SORTS[@sort], :id))

        @coa = Aim::Units.new
        @units_without_rules = units_without_rules
      end
    end

    def show
      @coa = Aim::CoaCodes.new(@rule.agency)
      @changes = @rule.changes_made.to_a
      @objections = []
    end

    def update
      @coa = Aim::CoaCodes.new(@rule.agency)
      attributes = params.require(:coding_rule).permit(*Aim::CodingRule::FIELDS, :encumbrance).to_h
      attributes = attributes.except('org_number').transform_values { |v| v.to_s.strip.presence }
      fills, linked = @coa.linkage(attributes)
      attributes.merge!(fills)
      unknown = @coa.invalid_fields(attributes.slice(*Aim::CoaCodes::LISTS.keys))
      objections = unknown.map { |f| "#{helpers.aim_coding_field_label(f)} #{attributes[f].inspect} is not in the COA for #{@rule.agency}" } + linked
      if objections.any? && params[:save_anyway].blank?
        @rule.assign_attributes(attributes)
        @changes = @rule.changes_made.to_a
        @objections = objections
        return render :show, status: :unprocessable_content
      end

      @rule.apply_edits!(attributes.merge(warnings: objections.join('; ').presence), by: current_user_email)
      redirect_to aim_coding_rule_path(@rule), notice: objections.any? ? 'Saved, with the COA\'s objection kept as a warning.' : 'Saved.'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to aim_coding_rule_path(@rule), alert: e.message
    end

    # Retired today: in effect through yesterday, so nothing already coded is
    # touched and nothing new takes it.
    def retire
      @rule.retire!(on: Date.current - 1, by: current_user_email)
      redirect_to aim_coding_rule_path(@rule), notice: 'Retired. It no longer applies to new invoices.'
    end

    private

    def set_rule
      @rule = Aim::CodingRule.find(params[:id])
      return if group_serves_unit?(@rule.agency, @rule.budget_unit)

      redirect_to aim_coding_rules_path, alert: 'That rule is for a budget unit outside your agency groups.'
    end

    # The rules and units of the agency groups picked in Managing (#131).
    def managed_unit?(agency, unit) = group_serves_unit?(agency, unit, helpers.aim_managing_groups)

    def managed(rules) = rules.to_a.select { |rule| managed_unit?(rule.agency, rule.budget_unit) }

    def filtered_rules
      scope = Aim::CodingRule.for_agency(@agency)
      scope = scope.in_effect if @show == 'in_effect'
      scope = scope.where(budget_unit: @unit) if @unit
      scope
    end

    # AIM's budget units in this agency with no rule in effect.
    def units_without_rules
      covered = Aim::CodingRule.for_agency(@agency).in_effect.distinct.pluck(:budget_unit)
      @coa.all.select { |unit| unit.agency == @agency && managed_unit?(unit.agency, unit.unit) }.map(&:unit) - covered
    rescue ActiveRecord::ActiveRecordError
      []
    end

    # The rules shown, in the template's layout plus each rule's id, to edit
    # in bulk and load again. Every value is text (codes too), so a cell that
    # would run as a formula is defused; Aim::LookupFile undoes that on load.
    def export_csv
      CSV.generate do |csv|
        csv << Aim::LookupFile::EXPORT
        @rules.each do |r|
          csv << Paperboy::CsvSafe.defuse_row(
            [r.vendor_name, r.customer_number, r.budget_unit, r.encumbrance, r.ma_number, r.vendor_code, r.fund,
             r.department, r.object_code, r.activity, r.function_code, r.major_program, r.program, r.phase, r.task,
             r.notes, r.id]
          )
        end
      end
    end
  end
end
