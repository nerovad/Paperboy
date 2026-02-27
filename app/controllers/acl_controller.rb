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
  ].freeze

  def index
    @groups = Group.all.order(:group_name)
    @group_member_counts = EmployeeGroup.group(:group_id).count
  end

  def show
    @members = @group.employees.order(:last_name, :first_name)

    if params[:search].present?
      search = params[:search].strip
      sanitized = ActiveRecord::Base.sanitize_sql_like(search)
      @search_results = Employee
        .where("first_name ILIKE :q OR last_name ILIKE :q OR CAST(employee_id AS TEXT) LIKE :q",
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

  private

  def set_group
    @group = Group.find(params[:id])
  end

  def group_params
    params.require(:group).permit(:group_name, :description)
  end
end
