# frozen_string_literal: true

# app/controllers/critical_information_authorizations_controller.rb
#
# The Critical Information Reporting side of the authorization console. A CIR
# is routed entirely by its "Where: Location" field, so this console manages one
# thing: which incident manager covers each site on the form.
#
# The mapping used to be a hardcoded hash in CriticalInformationLocationRouter,
# which is why this console exists — the list changes when people change roles,
# and it should not take a deploy.
class CriticalInformationAuthorizationsController < ApplicationController
  before_action :require_cir_auth_console
  before_action :set_authorization, only: %i[edit update destroy]

  # Assignment filter values. "unassigned" is the reason this filter exists:
  # 41 of the form's sites arrived here with no manager at all, and finding
  # them among 212 cards otherwise means scrolling for them.
  ASSIGNMENT_FILTERS = %w[assigned unassigned].freeze

  def index
    scoped = CriticalInformationAuthorization.order(:location).to_a

    @location_filter   = Array(params[:location]).reject(&:blank?)
    @employee_filter   = Array(params[:employee_id]).reject(&:blank?)
    @assignment_filter = params[:assignment].to_s.presence_in(ASSIGNMENT_FILTERS)

    @location_filter_options = CriticalInformationLocation.options
    @employee_filter_options = employee_filter_options(scoped)

    scoped = scoped.select { |a| @employee_filter.include?(a.employee_id.to_s) } if @employee_filter.any?

    @cards = CriticalInformationConsoleCards.new(
      scoped, locations: @location_filter, employee_ids: @employee_filter, assignment: @assignment_filter
    ).to_a
    @total_sites = CriticalInformationLocation::ALL.size
    @assigned_count = CriticalInformationAuthorization.count
  end

  def new
    @authorization = CriticalInformationAuthorization.new(location: params[:location])
    load_form_options
  end

  def create
    @authorization = CriticalInformationAuthorization.new(critical_information_authorization_params)
    @authorization.authorized_by = session.dig(:user, 'employee_id').to_s

    if @authorization.save
      redirect_to critical_information_authorizations_path(location: [@authorization.location]),
                  notice: 'Incident manager authorization added successfully.'
    else
      load_form_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form_options
  end

  def update
    if @authorization.update(critical_information_authorization_params)
      redirect_to critical_information_authorizations_path(location: [@authorization.location]),
                  notice: 'Incident manager authorization updated successfully.'
    else
      load_form_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    location = @authorization.location
    @authorization.destroy
    redirect_to critical_information_authorizations_path(location: [location]),
                notice: 'Incident manager authorization removed.'
  end

  private

  def set_authorization
    @authorization = CriticalInformationAuthorization.find_by(id: params[:id])
    return if @authorization

    redirect_to critical_information_authorizations_path, alert: 'Authorization not found.'
  end

  def load_form_options
    # An existing row keeps its own location selectable even if the catalogue
    # has since dropped that site, so the row stays editable and removable.
    @location_options = CriticalInformationLocation.options
    current = @authorization&.location
    @location_options += [[current, current]] if current.present? && !CriticalInformationLocation.include?(current)

    candidates = CriticalInformationAuthorization.manager_candidate_ids
    @manager_group_empty = candidates.empty?
    @employee_options = employee_options(candidates, @authorization&.employee_id)
  end

  # Candidate incident managers: members of the Critical_Incident_Managers
  # group, not every employee. The manager already on the row is kept in the
  # list so an existing authorization stays editable if they later leave.
  #
  # If nobody is in the group the console would otherwise offer an empty
  # dropdown, so it falls back to the managers already covering a site — the
  # form says so, because the fix is to populate the group. The matching
  # validation stands down the same way.
  def employee_options(candidate_ids, selected_employee_id = nil)
    ids = candidate_ids.presence || CriticalInformationAuthorization.distinct.pluck(:employee_id).map(&:to_s)
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

  def critical_information_authorization_params
    params.require(:critical_information_authorization).permit(:employee_id, :location)
  end
end
