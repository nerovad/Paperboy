# frozen_string_literal: true

module Aim
  # Admin -> Agency Groups (#131). Every agency AIM serves has its group;
  # AIM Admins make custom groups of an agency's BUs, rename and delete them,
  # and choose which groups each one's Fiscal also processes. Group Admins
  # open their own groups to set Fiscal people and settings.
  class AgencyGroupsController < BaseController
    before_action :require_group_admin
    before_action :require_aim_user_admin, only: %i[create update destroy]
    before_action :set_group, only: %i[show update destroy]

    def index
      reading_database('list the agency groups', alert: 'The agency groups could not be read.', empty: { groups: [] }) do
        Aim::AgencyGroup.ensure_agency_groups! if helpers.aim_user_admin?
        groups = helpers.aim_admin_groups
        @groups = groups.nil? ? Aim::AgencyGroups.new.all : groups
        @people = Aim::AgencyGroupRole.where(agency_group_id: @groups.map(&:id)).group(:agency_group_id, :role).count
        @agencies = Aim::Units.new.agencies
      end
    end

    def show
      @units = Aim::Units.new(every_agency: true)
      @resolver = helpers.aim_agency_groups
      @roles = @group.roles.order(:role, :employee_id).to_a
      @employees = Employee.where(id: @roles.map(&:employee_id)).index_by(&:id)
    end

    # A custom group of an agency's BUs; its BUs are ticked on its page.
    def create
      group = Aim::AgencyGroup.create!(name: params[:name], agency_id: params[:agency_id], custom: true,
                                       updated_by: current_user_email)
      redirect_to aim_agency_group_path(group), notice: 'Made. Tick its budget units below.'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to aim_agency_groups_path, alert: e.record.errors.full_messages.to_sentence
    end

    def update
      @group.update!(name: params[:name], updated_by: current_user_email)
      redirect_to aim_agency_group_path(@group), notice: 'Renamed.'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to aim_agency_group_path(@group), alert: e.record.errors.full_messages.to_sentence
    end

    # Only a custom group goes; its BUs go back to their agency's group.
    def destroy
      return redirect_to(aim_agency_group_path(@group), alert: "An agency's own group stays.") unless @group.custom

      @group.destroy!
      redirect_to aim_agency_groups_path, notice: "#{@group.name} deleted. Its budget units are back in their agency's group."
    end

    private

    def require_group_admin
      return if helpers.aim_group_admin?

      redirect_to aim_root_path, alert: 'Only AIM Admins and Group Admins manage agency groups.'
    end

    def set_group
      @group = Aim::AgencyGroup.find_by(id: params[:id])
      groups = helpers.aim_admin_groups
      return if @group && (groups.nil? || groups.any? { |g| g.id == @group.id })

      redirect_to aim_agency_groups_path, alert: 'That agency group is not one of yours.'
    end
  end
end
