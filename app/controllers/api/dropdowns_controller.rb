class Api::DropdownsController < ApplicationController
  def divisions
    divisions = Division.where(Agency: params[:agency])
                        .select(:Division, :LongName)
                        .distinct
                        .map { |d| { value: d.Division, label: "#{d.LongName}" } }

    render json: divisions
  end

  def departments
    departments = Department.where(Agency: params[:agency], Division: params[:division])
                            .select(:Department, :LongName)
                            .distinct
                            .map { |d| { value: d.Department, label: "#{d.LongName}" } }

    render json: departments
  end

  def units
    units = Unit.where(Agency: params[:agency], Division: params[:division], Department: params[:department])
                .select(:Unit, :LongName)
                .distinct
                .map { |u| { value: u.Unit, label: "#{u.Unit} #{u.LongName}" } }

    render json: units
  end
end

