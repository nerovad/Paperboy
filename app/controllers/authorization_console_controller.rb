# app/controllers/authorization_console_controller.rb
require "csv"

class AuthorizationConsoleController < ApplicationController
  before_action :require_auth_console
  before_action :set_managed_departments
  
  def index
    @department_id = params[:department_id].presence || "all"
    managed_dept_ids = @managed_departments.map(&:department_id)

    if @department_id == "all"
      @department = nil
      @authorized_approvers = AuthorizedApprover
        .where(department_id: managed_dept_ids)
        .order(:employee_id, :service_type)
        .to_a
    elsif managed_dept_ids.include?(@department_id)
      @department = Department.find_by(department_id: @department_id)

      # Find all budget-unit IDs that belong to this department
      dept_unit_ids = Unit.where(department_id: @department_id)
                         .pluck(:unit_id).map(&:to_s).to_set

      # Show approvers whose budget units overlap with this department's
      # units, OR whose department_id matches when no units are specified.
      @authorized_approvers = AuthorizedApprover
        .where(department_id: managed_dept_ids)
        .order(:employee_id, :service_type)
        .select { |a|
          if a.budget_units.present?
            (a.budget_units.split(",").map(&:strip).to_set & dept_unit_ids).any?
          else
            a.department_id == @department_id
          end
        }
    end

    scoped = @authorized_approvers || []

    # Filter dropdown options are built from the department-scoped set (before
    # the employee/service/location filters apply) so you can always switch.
    @employee_filter_options = Employee.where(id: scoped.map(&:employee_id).uniq)
                                       .sort_by { |e| [e.last_name.to_s, e.first_name.to_s] }
                                       .map { |e| ["#{e.first_name} #{e.last_name} (#{e.id})", e.id.to_s] }
    @service_type_filter_options = scoped.map(&:service_type).uniq
                                         .sort_by { |s| SERVICE_ORDER.index(s) || 99 }
                                         .map { |s| [AuthorizedApprover::SERVICE_TYPES[s] || s, s] }
    @location_filter_options = scoped.flat_map { |a| Array(a.locations) }.uniq.sort

    @employee_id_filter  = params[:employee_id].presence
    @service_type_filter = params[:service_type].presence
    @location_filter     = params[:location].presence

    scoped = scoped.select { |a| a.employee_id.to_s == @employee_id_filter } if @employee_id_filter
    scoped = scoped.select { |a| a.service_type == @service_type_filter }    if @service_type_filter
    scoped = scoped.select { |a| Array(a.locations).include?(@location_filter) } if @location_filter

    @authorized_approvers = scoped
    @groups_by_employee = build_groups(scoped)

    respond_to do |format|
      format.html
      format.csv do
        send_data authorized_approvers_csv(scoped),
                  filename: "authorized_approvers_#{@department_id}_#{Date.current}.csv",
                  type: "text/csv"
      end
    end
  end
  
  def new
    @department_id = params[:department_id]
    @authorized_approver = AuthorizedApprover.new(department_id: @department_id)
    @selected_service_types = []
    @selected_key_types = []

    @location_options     = location_options
    @budget_unit_options  = fetch_managed_budget_units
    @department_employees = fetch_managed_employees
  end

  def create
    raw = authorized_approver_create_params
    service_types = Array(raw.delete(:service_type)).reject(&:blank?)
    key_types     = Array(raw.delete(:key_types)).reject(&:blank?)
    authorized_by = session.dig(:user, "employee_id").to_s
    @selected_service_types = service_types
    @selected_key_types     = key_types

    if service_types.empty?
      @authorized_approver = AuthorizedApprover.new(raw)
      @authorized_approver.authorized_by = authorized_by
      @authorized_approver.errors.add(:service_type, "must be selected")
      return rerender_new
    end

    approvers = build_approvers(raw, service_types, key_types, authorized_by)
    approvers.each { |a| resolve_department_from_units(a) }

    if approvers.all?(&:valid?)
      AuthorizedApprover.transaction { approvers.each(&:save!) }
      count = approvers.size
      noun = count == 1 ? "authorization" : "authorizations"
      redirect_to authorization_console_index_path(department_id: approvers.first.department_id),
                  notice: "#{count} approver #{noun} added successfully."
    else
      @authorized_approver = approvers.find { |a| a.errors.any? } || approvers.first
      rerender_new
    end
  end
  
  # Edit a whole authorization group (all service/key-type rows that share the
  # same employee/dept/span/budget/locations), identified by ids[].
  def group_edit
    records = scoped_group(params[:ids])
    return redirect_to(authorization_console_index_path, alert: "Authorization not found.") if records.empty?

    rep = records.first
    @authorized_approver = AuthorizedApprover.new(
      employee_id: rep.employee_id, department_id: rep.department_id,
      span: rep.span, budget_units: rep.budget_units, locations: rep.locations
    )
    @selected_service_types = records.map(&:service_type).uniq
    @selected_key_types     = records.map(&:key_type).compact.uniq
    @original_ids           = records.map(&:id)
    @department_id          = rep.department_id
    load_form_options
    render :group_edit
  end

  # Replace the group: delete the old rows and recreate from the submission.
  def group_update
    records = scoped_group(params[:ids])
    raw = authorized_approver_create_params
    service_types = Array(raw.delete(:service_type)).reject(&:blank?)
    key_types     = Array(raw.delete(:key_types)).reject(&:blank?)
    authorized_by = session.dig(:user, "employee_id").to_s
    @selected_service_types = service_types
    @selected_key_types     = key_types
    @original_ids           = records.map(&:id)

    approvers = build_approvers(raw, service_types, key_types, authorized_by)
    approvers.each { |a| resolve_department_from_units(a) }

    saved = false
    if service_types.any?
      begin
        AuthorizedApprover.transaction do
          records.each(&:destroy!)
          approvers.each(&:save!)
        end
        saved = true
      rescue ActiveRecord::RecordInvalid
        saved = false
      end
    end

    if saved
      redirect_to authorization_console_index_path(department_id: approvers.first.department_id),
                  notice: "Authorization updated successfully."
    else
      @authorized_approver = approvers.find { |a| a.errors.any? } || AuthorizedApprover.new(raw)
      @authorized_approver.errors.add(:service_type, "must be selected") if service_types.empty?
      @department_id = raw[:department_id]
      load_form_options
      render :group_edit, status: :unprocessable_entity
    end
  end

  def group_destroy
    records = scoped_group(params[:ids])
    dept = records.first&.department_id
    AuthorizedApprover.where(id: records.map(&:id)).destroy_all
    redirect_to authorization_console_index_path(department_id: dept),
                notice: "Authorization removed."
  end
  
  def destroy_all_for_employee
    employee_id   = params[:employee_id]
    department_id = params[:department_id]
    
    AuthorizedApprover.where(employee_id: employee_id, department_id: department_id).destroy_all
    
    redirect_to authorization_console_index_path(department_id: department_id),
                notice: "All authorizations removed for employee #{employee_id}."
  end
  
  private

  # Collapse per-(service_type, key_type) rows into one group per real
  # authorization (same employee/dept/span/budget/locations) for display.
  def build_groups(approvers)
    approvers.group_by(&:employee_id).transform_values do |recs|
      recs.group_by { |a| [a.department_id, a.span, a.budget_units, Array(a.locations).sort] }.values.map do |g|
        { ids:           g.map(&:id),
          record:        g.first,
          service_types: g.map(&:service_type).uniq.sort_by { |s| SERVICE_ORDER.index(s) || 99 },
          key_types:     g.map(&:key_type).compact.uniq.sort }
      end
    end
  end

  # Fan a multi-select submission out to one record per service type, and one
  # per key type for the 'K' service. Shared by create and group_update.
  def build_approvers(shared, service_types, key_types, authorized_by)
    service_types.flat_map do |st|
      kts = st == "K" ? (key_types.presence || [nil]) : [nil]
      kts.map do |kt|
        a = AuthorizedApprover.new(shared.merge(service_type: st, key_type: kt))
        a.authorized_by = authorized_by
        a
      end
    end
  end

  def scoped_group(ids)
    AuthorizedApprover.where(id: Array(ids), department_id: @managed_departments.map(&:department_id)).to_a
  end

  def load_form_options
    @department_employees = fetch_managed_employees
    @location_options     = location_options
    @budget_unit_options  = fetch_managed_budget_units
  end

  # Flatten the (already access-scoped) approver list into CSV rows. Employee
  # names and department names are batch-loaded to avoid per-row lookups.
  SERVICE_ORDER = %w[P E V C K].freeze

  def authorized_approvers_csv(approvers)
    emps  = Employee.where(id: approvers.map(&:employee_id).uniq).index_by { |e| e.id.to_s }
    depts = Department.where(department_id: approvers.map(&:department_id).uniq).index_by(&:department_id)

    # Collapse the per-service-type rows back into one line per real
    # authorization (same employee/dept/span/budget/locations).
    groups = approvers.group_by { |a| [a.employee_id, a.department_id, a.span, a.budget_units, Array(a.locations).sort] }

    CSV.generate do |csv|
      csv << ["Employee ID", "Employee Name", "Department ID", "Department", "Service Types",
              "Key Types", "Span", "Budget Units", "Locations", "Authorized By", "Created At"]
      groups.each do |(emp_id, dept_id, span, budget, locations), rows|
        e = emps[emp_id.to_s]
        service_types = rows.map(&:service_type).uniq.sort_by { |s| SERVICE_ORDER.index(s) || 99 }
        key_types     = rows.map(&:key_type).compact.uniq.sort
        csv << [emp_id,
                (e && "#{e.first_name} #{e.last_name}"),
                dept_id,
                depts[dept_id]&.long_name,
                service_types.join(","),
                key_types.join(","),
                span,
                budget,
                locations.join(" | "),
                rows.first.authorized_by,
                rows.first.created_at&.strftime("%Y-%m-%d")]
      end
    end
  end

  def set_managed_departments
    if auth_console_admin?
      @managed_departments = Department.order(:department_id).to_a
    else
      dept_id = current_user_org_chain[:department_id]
      dept = dept_id ? Department.find_by(department_id: dept_id) : nil
      @managed_departments = [dept].compact
    end
  end
  
  def fetch_managed_employees
    dept_ids = @managed_departments.map(&:department_id)
    return [] if dept_ids.empty?

    unit_ids = Unit.where(department_id: dept_ids).pluck(:unit_id)
    employees = Employee.where(unit: unit_ids).order(:last_name, :first_name)

    employees.map do |e|
      {
        id: e.employee_id,
        name: "#{e.first_name} #{e.last_name} (#{e.employee_id})",
        email: e.email
      }
    end
  end
  
  def location_options
    Building.for_authorization_console
            .order(:occupant_description, :address)
            .map(&:location_label)
            .reject(&:blank?)
            .uniq
            .map { |label| [label, label] }
  end

  def fetch_managed_budget_units
    dept_ids = @managed_departments.map(&:department_id)
    return [] if dept_ids.empty?

    dept_names = @managed_departments.index_by(&:department_id)
    Unit.where(department_id: dept_ids).order(:unit_id).map do |u|
      label = "#{u.unit_id} - #{dept_names[u.department_id]&.long_name}"
      [label, u.unit_id.to_s]
    end
  end

  # Derive department_id from the first selected budget unit's actual department.
  # Falls back to the existing department_id when no budget units are selected.
  def resolve_department_from_units(approver)
    return if approver.budget_units.blank?

    first_unit_id = approver.budget_units.split(",").first&.strip
    return if first_unit_id.blank?

    unit = Unit.find_by(unit_id: first_unit_id)
    approver.department_id = unit.department_id if unit&.department_id.present?
  end

  def authorized_approver_params
    raw = params.require(:authorized_approver).permit(
      :employee_id,
      :department_id,
      :service_type,
      :key_type,
      :span,
      locations: [],
      budget_units: []
    )

    # locations is a JSON array column; budget_units stays a comma-joined string.
    raw[:locations]     = Array(raw[:locations]).reject(&:blank?)
    raw[:budget_units]  = Array(raw[:budget_units]).reject(&:blank?).join(",")

    raw
  end

  def authorized_approver_create_params
    raw = params.require(:authorized_approver).permit(
      :employee_id,
      :department_id,
      :span,
      service_type: [],
      key_types: [],
      locations: [],
      budget_units: []
    )

    raw[:locations]    = Array(raw[:locations]).reject(&:blank?)
    raw[:budget_units] = Array(raw[:budget_units]).reject(&:blank?).join(",")

    raw
  end

  def rerender_new
    @department_id        = @authorized_approver.department_id
    @department_employees = fetch_managed_employees
    @location_options     = location_options
    @budget_unit_options  = fetch_managed_budget_units
    render :new, status: :unprocessable_entity
  end
end
