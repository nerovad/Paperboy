# frozen_string_literal: true

module Aim
  # The vendor aliases the AI matches against: list, teach, correct, remove.
  class VendorAliasesController < BaseController
    before_action :require_aim_admin
    before_action :set_alias, only: %i[update destroy]

    def index
      @aliases = Aim::VendorAlias.by_name.to_a
      @filter = params[:q].to_s.squish
      return if @filter.blank?

      needle = @filter.downcase
      @aliases.select! { |row| row.extracted_name.downcase.include?(needle) || row.normalized_name.downcase.include?(needle) }
    end

    def create
      Aim::VendorAlias.learn!(extracted_name: params[:extracted_name], normalized_name: params[:normalized_name],
                              learned_by: current_user_email, note: params[:note].presence)
      redirect_to aim_vendor_aliases_path, notice: 'Alias saved.'
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      redirect_to aim_vendor_aliases_path, alert: e.message
    end

    def update
      @alias.update!(normalized_name: params[:normalized_name], note: params[:note].presence, learned_by: current_user_email)
      redirect_to aim_vendor_aliases_path, notice: 'Alias updated.'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to aim_vendor_aliases_path, alert: e.message
    end

    def destroy
      @alias.destroy!
      redirect_to aim_vendor_aliases_path, notice: 'Alias removed.'
    end

    private

    def set_alias
      @alias = Aim::VendorAlias.find(params[:id])
    end
  end
end
