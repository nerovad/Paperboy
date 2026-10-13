# frozen_string_literal: true

module Aim
  # An agency group's Fiscal settings (#131): the report's columns, their
  # order and header names, and its format,
  # hold reasons, tag suggestions, and what must be filled in before archive.
  # Group Admins and AIM Admins. Which groups its Fiscal also processes is
  # AIM Admins' alone.
  class AgencyGroupSettingsController < BaseController
    before_action :set_group

    def update
      @group.assign_attributes(settings.merge(updated_by: current_user_email))
      cover if params.key?(:covered_group_ids) && helpers.aim_user_admin?
      @group.save!
      redirect_to aim_agency_group_path(@group, anchor: 'settings'), notice: 'Settings saved.'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to aim_agency_group_path(@group, anchor: 'settings'), alert: e.record.errors.full_messages.to_sentence
    end

    private

    def set_group
      @group = Aim::AgencyGroup.find_by(id: params[:id])
      groups = helpers.aim_admin_groups
      return if @group && (groups.nil? || groups.any? { |g| g.id == @group.id })

      redirect_to aim_root_path, alert: 'Only AIM Admins and its Group Admins change an agency group.'
    end

    # A blank tag list keeps none; AIM's defaults are what the box starts with.
    def settings
      {
        export_format: params[:export_format].presence || @group.export_format,
        export_column_list: Array(params[:export_columns]),
        export_headers: params.fetch(:export_headers, {}).permit(*Aim::FiscalExport::COLUMNS).to_h,
        hold_reasons: params[:hold_reasons].to_s.strip.presence,
        tag_suggestions: params.key?(:tag_suggestions) ? params[:tag_suggestions].to_s.strip : @group.tag_suggestions,
        required_field_list: Array(params[:required_fields])
      }
    end

    # Fiscal also processes: the groups ticked, never the group itself.
    def cover
      ids = Array(params[:covered_group_ids]).compact_blank.map(&:to_i) - [@group.id]
      ids &= Aim::AgencyGroup.where(id: ids).pluck(:id)
      @group.coverages.where.not(covered_group_id: ids).delete_all
      (ids - @group.coverages.pluck(:covered_group_id)).each do |id|
        @group.coverages.create!(covered_group_id: id, added_by: current_user_email)
      end
    end
  end
end
