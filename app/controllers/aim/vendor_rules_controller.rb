# frozen_string_literal: true

module Aim
  # Vendor-specific extraction hints: list, add, edit, remove.
  class VendorRulesController < BaseController
    before_action :require_aim_admin
    before_action :set_rule, only: %i[update destroy]

    def index
      @rules = Aim::VendorRule.by_name.to_a
    end

    def create
      Aim::VendorRule.create!(vendor_name: params[:vendor_name], rules: params[:rules], updated_by: current_user_email)
      redirect_to aim_vendor_rules_path, notice: 'Rules saved.'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to aim_vendor_rules_path, alert: e.message
    end

    def update
      @rule.update!(vendor_name: params[:vendor_name].presence || @rule.vendor_name, rules: params[:rules],
                    updated_by: current_user_email)
      redirect_to aim_vendor_rules_path, notice: 'Rules updated.'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to aim_vendor_rules_path, alert: e.message
    end

    def destroy
      @rule.destroy!
      redirect_to aim_vendor_rules_path, notice: 'Rules removed.'
    end

    private

    def set_rule
      @rule = Aim::VendorRule.find(params[:id])
    end
  end
end
