# app/controllers/lookups_controller.rb
class LookupsController < ApplicationController
    def divisions
    @division_options = Division
      .where(agency_id: params[:agency])
      .order(:long_name)
      .pluck(:long_name, :division_id)

    Rails.logger.info "[LOOKUPS] agency=#{params[:agency]} → #{@division_options.size} divisions"

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

    Rails.logger.info "[LOOKUPS] division=#{params[:division]} → #{@department_options.size} departments"

    respond_to do |format|
      format.turbo_stream
      format.html { head :not_acceptable }
    end
  end


  def units
    @unit_options = Unit
      .where(department_id: params[:department])
      .order(:short_name)
      .pluck(:short_name, :unit_id)

    Rails.logger.info "[LOOKUPS] department=#{params[:department]} → #{@unit_options.size} units"

    respond_to do |format|
      format.turbo_stream
      format.html { head :not_acceptable }
    end
  end
end 
