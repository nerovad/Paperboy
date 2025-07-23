class LookupsController < ApplicationController
  def divisions
    @division_options = Division.where(Agency: params[:agency])
    respond_to(&:turbo_stream)
  end

  def departments
    @department_options = Department.where(Division: params[:division])
    respond_to(&:turbo_stream)
  end

  def units
    @unit_options = Unit.where(Department: params[:department])
    respond_to(&:turbo_stream)
  end
end
