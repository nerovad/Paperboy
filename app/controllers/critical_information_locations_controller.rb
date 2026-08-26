# frozen_string_literal: true

# app/controllers/critical_information_locations_controller.rb
#
# The site catalogue behind the Critical Information Reporting form's "Where:
# Location" dropdown. It used to be a frozen array in the code, so opening or
# closing a site took a deploy.
#
# Add and delete only. There is no rename: the name is stored verbatim on every
# report already filed, so changing it would orphan them. Closing a site and
# opening the new spelling is the honest way to do that, and leaves the old
# reports readable.
class CriticalInformationLocationsController < ApplicationController
  before_action :require_cir_auth_console
  before_action -> { require_cir_auth_console('write') }, only: %i[new create]
  before_action -> { require_cir_auth_console('delete') }, only: %i[destroy]

  def new
    @location = CriticalInformationLocation.new(name: params[:name])
  end

  def create
    @location = CriticalInformationLocation.new(critical_information_location_params)
    @location.created_by = session.dig(:user, 'employee_id').to_s

    if @location.save
      redirect_to critical_information_authorizations_path(location: [@location.name]),
                  notice: "#{@location.name} added. Assign an incident manager so reports from it reach someone."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Deleting a site takes its authorization with it — the pair only means
  # anything together. Reports already filed against the name keep it: they are
  # records of what was submitted, not references to this table.
  def destroy
    location = CriticalInformationLocation.find_by(id: params[:id])
    return redirect_to(critical_information_authorizations_path, alert: 'Location not found.') if location.nil?

    CriticalInformationLocation.transaction do
      CriticalInformationAuthorization.for_location(location.name).destroy_all
      location.destroy!
    end

    redirect_to critical_information_authorizations_path,
                notice: "#{location.name} removed from the form."
  end

  private

  def critical_information_location_params
    params.require(:critical_information_location).permit(:name)
  end
end
