# app/controllers/authorization_forms_controller.rb
class AuthorizationFormsController < ApplicationController
  before_action :set_authorization_form, only: [:show, :pdf, :approve, :deny]

  def new
    @authorization_form = AuthorizationForm.new

    employee_id = session.dig(:user, "employee_id").to_s
    @employee   = employee_id.present? ? Employee.find_by(EmployeeID: employee_id) : nil

    unless @employee
      redirect_to login_path, alert: "Please sign in to start a submission." and return
    end

    # Org lookups
    unit        = Unit.find_by(unit_id: @employee["Unit"])
    department  = unit ? Department.find_by(department_id: unit["department_id"]) : nil
    division    = department ? Division.find_by(division_id: department["division_id"]) : nil
    agency      = division ? Agency.find_by(agency_id: division["agency_id"]) : nil

    # Prefill
    @prefill_data = {
      employee_id: @employee["EmployeeID"],
      name:        [@employee["First_Name"], @employee["Last_Name"]].compact.join(" "),
      phone:       @employee["Work_Phone"],
      email:       @employee["EE_Email"],
      agency:      agency&.agency_id,
      division:    division&.division_id,
      department:  department&.department_id,
      unit:        unit&.unit_id
    }

    # Dropdowns
    @agency_options = Agency.order(:long_name).pluck(:long_name, :agency_id)

    @division_options = if agency
      Division.where(agency_id: agency.agency_id).order(:long_name).pluck(:long_name, :division_id)
    else
      []
    end

    @department_options = if division
      Department.where(division_id: division.division_id).order(:long_name).pluck(:long_name, :department_id)
    else
      []
    end

    @unit_options = if department
      Unit.where(department_id: department.department_id)
          .order(:unit_id)
          .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }
    else
      []
    end
  end

  def create
    employee      = session[:user]
    employee_id   = employee["employee_id"].to_s
    supervisor_id = fetch_supervisor_id(employee_id)

    @authorization_form = AuthorizationForm.new(authorization_form_params)
    @authorization_form.employee_id = employee_id
    @authorization_form.status = 0  # submitted
    @authorization_form.supervisor_id = supervisor_id
    @authorization_form.supervisor_email = fetch_employee_email(supervisor_id)

    if @authorization_form.save
      redirect_to form_success_path, allow_other_host: false, status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show; end

  def pdf
    # Create PDF generator for authorization forms
    pdf_data = AuthorizationFormPdfGenerator.generate(@authorization_form)

    send_data pdf_data,
              filename: "AuthorizationForm_#{@authorization_form.id}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  def approve
    @submission = AuthorizationForm.find(params[:id])
    approver_id = session.dig(:user, "employee_id").to_s

    if @submission.submitted?
      # DEPT HEAD APPROVAL
      delegated_approver_id = params[:delegated_approver_id].to_s.strip

      if delegated_approver_id.blank?
        redirect_to inbox_queue_path, alert: "Please select a delegated approver." and return
      end

      delegated_approver_email = fetch_employee_email(delegated_approver_id)

      @submission.update!(
        status: 1,
        approved_by: approver_id,
        approved_at: Time.current,
        delegated_approver_id: delegated_approver_id,
        delegated_approver_email: delegated_approver_email
      )

      # Send notification to delegated approver
      SecurityMailer.notify_delegated_approver_auth(@submission).deliver_later

      redirect_to inbox_queue_path, notice: "Authorization form approved and sent to #{delegated_approver_id} for final approval."

    elsif @submission.pending_delegated_approval?
      # DELEGATED APPROVER APPROVAL
      @submission.update!(
        status: 3,
        delegated_approved_by: approver_id,
        delegated_approved_at: Time.current
      )

      # Send to Security
      NotifySecurityAuthJob.perform_later(@submission.id)
      
      @submission.update!(status: 4)

      redirect_to inbox_queue_path, notice: "Authorization form approved and sent to Security."
    else
      redirect_to inbox_queue_path, alert: "Invalid approval state."
    end
  end

  def deny
    @submission = AuthorizationForm.find(params[:id])
    denier_id = session.dig(:user, "employee_id").to_s
    reason = params[:denial_reason].to_s.strip

    @submission.update!(
      status: 2,
      denied_by: denier_id,
      denied_at: Time.current,
      denial_reason: reason.presence || "No reason provided"
    )

    SecurityMailer.denied_auth(@submission).deliver_later

    redirect_to inbox_queue_path, alert: "Authorization form denied."
  end

  private

  def set_authorization_form
    @authorization_form = AuthorizationForm.find(params[:id])
  end

  def fetch_supervisor_id(employee_id)
    result = ActiveRecord::Base.connection.exec_query(<<-SQL.squish).first
      SELECT Supervisor_ID
      FROM [GSABSS].[dbo].[Employees]
      WHERE EmployeeID = '#{employee_id}'
    SQL
    result&.fetch("Supervisor_ID", nil)
  end

  def fetch_employee_email(emp_id)
    return nil if emp_id.blank?
    row = ActiveRecord::Base.connection.exec_query(<<-SQL.squish).first
      SELECT EE_Email
      FROM [GSABSS].[dbo].[Employees]
      WHERE EmployeeID = '#{emp_id}'
    SQL
    row&.fetch("EE_Email", nil)
  end

  def authorization_form_params
    params.require(:authorization_form).permit(
      :name,
      :phone,
      :email,
      :agency,
      :division,
      :department,
      :unit,
      :service_type,
      :key_type,
      :budget_units
    )
  end
end
