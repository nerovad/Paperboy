# app/controllers/acl_controller.rb
class AclController < ApplicationController
  before_action :require_system_admin
  before_action :set_group, only: [:show, :edit, :update, :destroy, :add_member, :remove_member, :permissions, :update_permissions]

  DROPDOWN_ITEMS = [
    { key: 'inbox',        label: 'Inbox' },
    { key: 'submissions',  label: 'Submissions' },
    { key: 'reports',      label: 'Reports' },
    { key: 'dashboards',   label: 'Dashboards' },
    { key: 'manage_forms', label: 'Manage Forms' },
    { key: 'emulate',  label: 'Emulate' },
    { key: 'acl',          label: 'ACL' },
    { key: 'auth_console', label: 'Auth Console' },
    { key: 'lookup_tables', label: 'Lookup Tables' },
  ].freeze

  def index
    @groups = Group.all.order(:group_name)
    @group_member_counts = EmployeeGroup.group(:group_id).count
    @agency_options = Agency.order(:long_name).pluck(:long_name, :agency_id)
  end

  def show
    @members = @group.employees.order(:last_name, :first_name)

    if params[:search].present?
      search = params[:search].strip
      sanitized = ActiveRecord::Base.sanitize_sql_like(search)
      @search_results = Employee
        .where("First_Name LIKE :q OR Last_Name LIKE :q OR CAST(EmployeeID AS VARCHAR) LIKE :q",
               q: "%#{sanitized}%")
        .order(:last_name, :first_name)
        .limit(20)
    end
  end

  def new
    @group = Group.new
  end

  def create
    @group = Group.new(group_params)

    if @group.save
      redirect_to acl_index_path, notice: "Group created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @group.update(group_params)
      redirect_to acl_index_path, notice: "Group updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @group.group_permissions.destroy_all
    @group.employee_groups.destroy_all
    @group.destroy
    redirect_to acl_index_path, notice: "Group deleted."
  end

  def add_member
    employee_id = params[:employee_id]

    if employee_id.present? && !@group.employee_groups.exists?(employee_id: employee_id)
      @group.employee_groups.create!(employee_id: employee_id)
      redirect_to acl_path(@group), notice: "Member added."
    else
      redirect_to acl_path(@group), alert: "Employee is already a member or was not found."
    end
  end

  def remove_member
    eg = @group.employee_groups.find_by(employee_id: params[:employee_id])
    eg&.destroy
    redirect_to acl_path(@group), notice: "Member removed."
  end

  def permissions
    @dropdown_items = DROPDOWN_ITEMS
    @form_templates = FormTemplate.order(:name)
    @current_permissions = @group.group_permissions.pluck(:permission_type, :permission_key)
    @dropdown_keys = @current_permissions.select { |t, _| t == 'dropdown' }.map(&:last).to_set
    @form_keys = @current_permissions.select { |t, _| t == 'form' }.map(&:last).to_set
  end

  def update_permissions
    dropdown_keys = Array(params[:dropdown_permissions])
    form_keys = Array(params[:form_permissions])

    ActiveRecord::Base.transaction do
      @group.group_permissions.destroy_all

      dropdown_keys.each do |key|
        @group.group_permissions.create!(permission_type: 'dropdown', permission_key: key)
      end

      form_keys.each do |key|
        @group.group_permissions.create!(permission_type: 'form', permission_key: key)
      end
    end

    redirect_to acl_path(@group), notice: "Permissions updated successfully."
  end

  # --- Organization Permissions ---

  def org_permissions
    @dropdown_items = DROPDOWN_ITEMS
    @form_templates = FormTemplate.order(:name)

    @agency_id = params[:agency_id]
    @division_id = params[:division_id]
    @department_id = params[:department_id]
    @unit_id = params[:unit_id]

    # Build the org label for display
    @org_label = build_org_label

    # Load current permissions for this exact org level
    @current_org_permissions = OrgPermission.where(
      agency_id: @agency_id.presence,
      division_id: @division_id.presence,
      department_id: @department_id.presence,
      unit_id: @unit_id.presence
    ).pluck(:permission_type, :permission_key)

    @org_dropdown_keys = @current_org_permissions.select { |t, _| t == 'dropdown' }.map(&:last).to_set
    @org_form_keys = @current_org_permissions.select { |t, _| t == 'form' }.map(&:last).to_set
  end

  def update_org_permissions
    agency_id = params[:agency_id].presence
    division_id = params[:division_id].presence
    department_id = params[:department_id].presence
    unit_id = params[:unit_id].presence

    dropdown_keys = Array(params[:dropdown_permissions])
    form_keys = Array(params[:form_permissions])

    ActiveRecord::Base.transaction do
      OrgPermission.where(
        agency_id: agency_id,
        division_id: division_id,
        department_id: department_id,
        unit_id: unit_id
      ).destroy_all

      dropdown_keys.each do |key|
        OrgPermission.create!(
          agency_id: agency_id,
          division_id: division_id,
          department_id: department_id,
          unit_id: unit_id,
          permission_type: 'dropdown',
          permission_key: key
        )
      end

      form_keys.each do |key|
        OrgPermission.create!(
          agency_id: agency_id,
          division_id: division_id,
          department_id: department_id,
          unit_id: unit_id,
          permission_type: 'form',
          permission_key: key
        )
      end
    end

    redirect_to acl_index_path, notice: "Organization permissions updated successfully."
  end

  private

  def set_group
    @group = Group.find(params[:id])
  end

  def group_params
    params.require(:group).permit(:group_name, :description)
  end

  def build_org_label
    parts = []
    if @agency_id.present?
      agency = Agency.find_by(agency_id: @agency_id)
      parts << "Agency: #{agency&.long_name || @agency_id}"
    end
    if @division_id.present?
      division = Division.find_by(division_id: @division_id)
      parts << "Division: #{division&.long_name || @division_id}"
    end
    if @department_id.present?
      department = Department.find_by(department_id: @department_id)
      parts << "Department: #{department&.long_name || @department_id}"
    end
    if @unit_id.present?
      unit = Unit.find_by(unit_id: @unit_id)
      parts << "Unit: #{unit&.unit_id} - #{unit&.long_name || @unit_id}"
    end
    parts.join(" > ")
  end
end
