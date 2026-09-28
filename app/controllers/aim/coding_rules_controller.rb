# frozen_string_literal: true

module Aim
  # The coding lookups (item b.3): the rules by agency and budget unit, one
  # rule to edit with the COA checking every code (Save anyway keeps the
  # objection as a warning), its history, and Retire. Fiscal and AIM Admins.
  class CodingRulesController < BaseController
    before_action :require_fiscal
    before_action :set_rule, only: %i[show update retire]

    def index
      @agencies = Aim::CodingRule.distinct.order(:agency).pluck(:agency)
      @agency = @agencies.include?(params[:agency]) ? params[:agency] : @agencies.first
      @units = Aim::CodingRule.for_agency(@agency).distinct.order(:budget_unit).pluck(:budget_unit)
      @unit = params[:unit].presence
      @show = params[:show] == 'all' ? 'all' : 'in_effect'
      @rules = filtered_rules.order(:budget_unit, :vendor_key, :id).to_a
      @coa = Aim::Units.new
      @units_without_rules = units_without_rules
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error "AIM could not list the coding rules: #{e.message}"
      @rules = []
      @agencies = []
      @units = []
      @units_without_rules = []
      flash.now[:alert] = 'The coding rules could not be read.'
    end

    def show
      @changes = @rule.changes_made.to_a
      @objections = []
    end

    def update
      attributes = params.require(:coding_rule).permit(*Aim::CodingRule::FIELDS, :encumbrance).to_h
      attributes = attributes.transform_values { |v| v.to_s.strip.presence }
      objections = Aim::CoaCodes.new(@rule.agency).invalid_fields(attributes.slice(*Aim::CoaCodes::LISTS.keys))
      if objections.any? && params[:save_anyway].blank?
        @rule.assign_attributes(attributes)
        @changes = @rule.changes_made.to_a
        @objections = objections.map { |f| "#{helpers.aim_coding_field_label(f)} #{attributes[f].inspect} is not in the COA for #{@rule.agency}" }
        return render :show, status: :unprocessable_content
      end

      @rule.apply_edits!(attributes.merge(warnings: objections.any? ? objection_text(objections, attributes) : nil), by: current_user_email)
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
    end

    def filtered_rules
      scope = Aim::CodingRule.for_agency(@agency)
      scope = scope.in_effect if @show == 'in_effect'
      scope = scope.where(budget_unit: @unit) if @unit
      scope
    end

    # AIM's budget units in this agency with no rule in effect.
    def units_without_rules
      covered = Aim::CodingRule.for_agency(@agency).in_effect.distinct.pluck(:budget_unit)
      @coa.all.select { |unit| unit.agency == @agency }.map(&:unit) - covered
    rescue ActiveRecord::ActiveRecordError
      []
    end

    def objection_text(fields, attributes)
      fields.map { |f| "#{f.humanize.downcase} #{attributes[f].inspect} is not in the COA for #{@rule.agency}" }.join('; ')
    end
  end
end
