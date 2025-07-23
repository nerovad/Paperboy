class LookupsController < ApplicationController
  def divisions
    @division_options = Division.where(Agency: params[:agency])
    respond_to do |format|
      format.turbo_stream
    end
  end

  def departments
    @department_options = Department.where(Division: params[:division])
    respond_to do |format|
      format.turbo_stream
    end
  end

  def units
    @unit_options = Unit.where(Department: params[:department])
    respond_to do |format|
      format.turbo_stream
    end
  end
end
