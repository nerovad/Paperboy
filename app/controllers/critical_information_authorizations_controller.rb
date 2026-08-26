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
  # new/edit carry the form for write and the removal buttons for delete, so
  # either right opens them; saving still needs write.
  before_action -> { require_authorization_console_any(AuthorizationConsole::CIR, 'write', 'delete') },
                only: %i[new edit]
  before_action -> { require_cir_auth_console('write') }, only: %i[create update]
  before_action -> { require_cir_auth_console('delete') }, only: %i[destroy]
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

    catalogue = CriticalInformationLocation.ordered.to_a
    @location_filter_options = catalogue.map { |site| [site.name, site.name] }
    @employee_filter_options = employee_filter_options(scoped)

    scoped = scoped.select { |a| @employee_filter.include?(a.employee_id.to_s) } if @employee_filter.any?

    @cards = CriticalInformationConsoleCards.new(
      scoped, catalogue: catalogue, locations: @location_filter,
              employee_ids: @employee_filter, assignment: @assignment_filter
    ).to_a
    @total_sites    = catalogue.size
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
    @location_options += [[current, current]] if current.present? && !CriticalInformationLocation.exists_named?(current)

    @employee_options = employee_options(@authorization&.employee_id)

    # The catalogue row behind this authorization, so the page can offer to
    # delete the site itself. Nil on a bare "Add Incident Manager" where no
    # location has been picked yet, and on a row whose site is already gone.
    @location_record = CriticalInformationLocation.find_by(name: current)
  end

  # Candidate incident managers: everyone in the General Services Agency. The
  # manager already on the row is kept in the list so an existing authorization
  # stays editable if they later transfer out.
  def employee_options(selected_employee_id = nil)
    options = CriticalInformationAuthorization.manager_candidates.map { |e| employee_option(e) }
    return options if selected_employee_id.blank?
    return options if options.any? { |(_label, id)| id == selected_employee_id.to_s }

    selected = Employee.find_by(id: selected_employee_id.to_s)
    selected ? options + [employee_option(selected)] : options
  end

  def employee_option(employee)
    ["#{employee.first_name} #{employee.last_name} (#{employee.employee_id})", employee.employee_id.to_s]
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
