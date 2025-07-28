class LookupsController < ApplicationController
  def divisions
    @division_options = Division.where(Agency: params[:agency]).pluck(:LongName, :Division)
    respond_to do |format|
      format.turbo_stream
      format.html { head :not_acceptable }
      format.any  { head :unsupported_media_type }
    end
  end

  def departments
    @department_options = Department.where(Division: params[:division]).pluck(:LongName, :Department)
    respond_to do |format|
      format.turbo_stream
      format.html { head :not_acceptable }
      format.any  { head :unsupported_media_type }
    end
  end

  def units
    @unit_options = Unit.where(Department: params[:department]).pluck(:LongName, :Unit)
    respond_to do |format|
      format.turbo_stream
      format.html { head :not_acceptable }
      format.any  { head :unsupported_media_type }
    end
  end
end
