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

    TABS = { 'units' => 'Budget units', 'bu_people' => 'BUs & People', 'roles' => 'Group roles',
             'settings' => 'Fiscal settings' }.freeze

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
      @tab = TABS.key?(params[:tab]) ? params[:tab] : 'units'
      @units = Aim::Units.new(every_agency: true)
      @resolver = helpers.aim_agency_groups
      @roles = @group.roles.order(:role, :employee_id).to_a
      @employees = Employee.where(id: @roles.map(&:employee_id)).index_by(&:id)
      bu_people if @tab == 'bu_people'
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

    # The BUs & People tab: each of the group's units with the AIM users who
    # work it (home unit unless hidden, or granted), as the BU page counts
    # them, and their rows for the BU Admin and shared queue switches.
    def bu_people
      @bu_units = @resolver.units_of(@group).sort
      people = Aim::Users.all.pluck(:id, :agency, :unit, :first_name, :last_name)
      @names = people.to_h { |id, _, _, first, last| [id, Employee.format_picker_label(id, first, last)] }
      grants = Aim::UserBudgetUnit.where(employee_id: @names.keys).pluck(:employee_id, :budget_unit, :hidden)
      @by_unit = helpers.aim_people_by_unit(people.map { |id, agency, unit, _, _| [id, agency, unit] }, grants)
                        .slice(*@bu_units)
      @rows = Aim::UserBudgetUnit.where(budget_unit: @bu_units).index_by { |row| [row.employee_id, row.budget_unit] }
      @homes = Aim::Users.home_units(people.to_h { |id, agency, unit, _, _| [id, [agency, unit]] })
    end

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
