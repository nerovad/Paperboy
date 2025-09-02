# app/controllers/lookups_controller.rb
class LookupsController < ApplicationController
  def divisions
    @division_options = Division
      .where(agency_id: params[:agency])
      .order(:long_name)
      .pluck(:long_name, :division_id)

    respond_to do |format|
      format.turbo_stream
      format.html { head :not_acceptable }
    end
  end

  def departments
    @department_options = Department
      .where(division_id: params[:division])
      .order(:long_name)
      .pluck(:long_name, :department_id)

    respond_to do |format|
      format.turbo_stream
      format.html { head :not_acceptable }
    end
  end

  def units
    @unit_options = Unit
      .where(department_id: params[:department])
      .order(:unit_id) # or :long_name, your choice
      .map { |u| ["#{u.unit_id} - #{u.long_name}", u.unit_id] }  # <-- KEY CHANGE

    respond_to do |format|
      format.turbo_stream
      format.html { head :not_acceptable }
    end
  end
end
