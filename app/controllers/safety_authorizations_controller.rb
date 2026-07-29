# frozen_string_literal: true

# app/controllers/safety_authorizations_controller.rb
#
# The Safety Reporting side of the authorization console. Much smaller than the
# GSA services console: a Safety Report only needs to know which safety officer
# covers the submitter's org node, so there is no service type, budget unit or
# building to scope by.
#
# The org node is a GSABSS division under agency HCA. HCA reverses the middle
# two levels of the hierarchy, so every label the user sees says "Department"
# (via OrgLabels) while the column keeps the database's name.
class SafetyAuthorizationsController < ApplicationController
  before_action :require_safety_auth_console
  before_action :set_authorization, only: %i[edit update destroy]

  def index
    scoped = SafetyReportAuthorization.order(:division_id, :employee_id).to_a

    @division_filter = Array(params[:division_id]).reject(&:blank?)
    @employee_filter = Array(params[:employee_id]).reject(&:blank?)

    @division_filter_options = division_options
    @employee_filter_options = employee_filter_options(scoped)

    scoped = scoped.select { |a| @division_filter.include?(a.division_id.to_s) } if @division_filter.any?
    scoped = scoped.select { |a| @employee_filter.include?(a.employee_id.to_s) } if @employee_filter.any?

    @authorizations_by_division = group_by_division(scoped)
  end

  def new
    @authorization = SafetyReportAuthorization.new(division_id: params[:division_id])
    load_form_options
  end

  def create
    @authorization = SafetyReportAuthorization.new(safety_authorization_params)
    @authorization.authorized_by = session.dig(:user, 'employee_id').to_s

    if @authorization.save
      redirect_to safety_authorizations_path(division_id: [@authorization.division_id]),
                  notice: 'Safety officer authorization added successfully.'
    else
      load_form_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form_options
  end

  def update
    if @authorization.update(safety_authorization_params)
      redirect_to safety_authorizations_path(division_id: [@authorization.division_id]),
                  notice: 'Safety officer authorization updated successfully.'
    else
      load_form_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    division_id = @authorization.division_id
    @authorization.destroy
    redirect_to safety_authorizations_path(division_id: [division_id]),
                notice: 'Safety officer authorization removed.'
  end

  private

  def set_authorization
    @authorization = SafetyReportAuthorization.find_by(id: params[:id])
    return if @authorization

    redirect_to safety_authorizations_path, alert: 'Authorization not found.'
  end

  def load_form_options
    @division_options = division_options
    @employee_options = employee_options(@authorization&.employee_id)
  end

  # One card per org node, so the screen reads as "who covers this department".
  # Nodes with no officer are listed too — an unassigned department is exactly
  # what this console exists to catch. Rows whose division has since dropped out
  # of GSABSS still get a card so they can be seen and removed.
  def group_by_division(authorizations)
    assigned  = authorizations.group_by { |a| a.division_id.to_s }
    divisions = ordered_divisions
    divisions = divisions.select { |d| @division_filter.include?(d.division_id.to_s) } if @division_filter.any?

    cards = divisions.filter_map do |division|
      rows = assigned.delete(division.division_id.to_s) || []
      next if rows.empty? && @employee_filter.any?

      { division_id: division.division_id.to_s, label: "#{division.division_id} - #{division.long_name}",
        authorizations: rows }
    end

    cards + assigned.map do |division_id, rows|
      { division_id: division_id, label: "#{division_id} - (no longer in GSABSS)", authorizations: rows }
    end
  end

  # GSABSS has duplicate org rows; collapse by id the way the GSA console does.
  def ordered_divisions
    @ordered_divisions ||= Division.where(agency_id: SafetyReportAuthorization::AGENCY_ID)
                                   .order(:long_name)
                                   .to_a
                                   .uniq(&:division_id)
  end

  def division_options
    ordered_divisions.map { |d| ["#{d.division_id} - #{d.long_name}", d.division_id.to_s] }
  end

  # Candidate safety officers: members of the HCA_Safety_Officers group, not
  # every HCA employee. The officer already on the row is kept in the list so
  # an existing authorization stays editable if they later leave the group.
  def employee_options(selected_employee_id = nil)
    ids = SafetyReportAuthorization.officer_candidate_ids
    ids |= [selected_employee_id.to_s] if selected_employee_id.present?
    return [] if ids.empty?

    Employee.where(id: ids)
            .order(:last_name, :first_name)
            .map { |e| ["#{e.first_name} #{e.last_name} (#{e.employee_id})", e.employee_id.to_s] }
  end

  def employee_filter_options(authorizations)
    Employee.where(id: authorizations.map(&:employee_id).uniq)
            .sort_by { |e| [e.last_name.to_s, e.first_name.to_s] }
            .map { |e| ["#{e.first_name} #{e.last_name} (#{e.employee_id})", e.employee_id.to_s] }
  end

  def safety_authorization_params
    params.require(:safety_report_authorization).permit(:employee_id, :division_id)
  end
end
