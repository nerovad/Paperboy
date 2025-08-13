# app/controllers/lookups_controller.rb
class LookupsController < ApplicationController
  def divisions
    @division_options =
      Division.where(agency_id: params[:agency])
              .order(:long_name)
              .pluck(:long_name, :division_id)

    respond_to do |format|
      format.turbo_stream
      format.html { head :not_acceptable }
      format.any  { head :unsupported_media_type }
    end
  end

  def departments
    @department_options =
      Department.where(division_id: params[:division])
                .order(:long_name)
                .pluck(:long_name, :department_id)

    respond_to do |format|
      format.turbo_stream
      format.html { head :not_acceptable }
      format.any  { head :unsupported_media_type }
    end
  end

  def units
    # display text: "1234 - Short Name", value: unit_id
    @unit_options =
      Unit.where(department_id: params[:department])
          .order(:short_name)
          .map { |u| ["#{u.unit_id} - #{u.short_name}", u.unit_id] }

    respond_to do |format|
      format.turbo_stream
      format.html { head :not_acceptable }
      format.any  { head :unsupported_media_type }
    end
  end
end
