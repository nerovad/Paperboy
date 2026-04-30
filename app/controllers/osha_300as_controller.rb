class Osha300asController < ApplicationController
  before_action :require_osha_log_access
  before_action :set_year_and_records

  def show
    @totals = Osha300aTotals.for(@year)
  end

  def update
    if @entry.submitted? && entry_params[:change_reason].to_s.strip.empty?
      flash.now[:alert] = "This year's 300A has already been submitted. Provide a Change Reason to amend it."
      @totals = Osha300aTotals.for(@year)
      return render :show, status: :unprocessable_entity
    end

    OshaEstablishment.transaction do
      if params[:osha_establishment].present?
        @establishment.assign_attributes(establishment_params)
      end

      @entry.assign_attributes(entry_params) if params[:osha_300a_entry].present?

      if @establishment.save && @entry.save
        redirect_to osha_300a_path(year: @year), notice: "300A summary saved."
      else
        flash.now[:alert] = (@establishment.errors.full_messages + @entry.errors.full_messages).join('; ')
        @totals = Osha300aTotals.for(@year)
        render :show, status: :unprocessable_entity
      end
    end
  end

  def payload
    return redirect_to(osha_300a_path(year: @year), alert: "Establishment and workforce must be saved first.") \
      unless @establishment.persisted? && @entry.persisted?

    payload_json = Osha300aPayloadBuilder.new(
      establishment: @establishment,
      entry:         @entry,
      totals:        Osha300aTotals.for(@year)
    ).to_json

    send_data payload_json,
              filename: "osha_300a_#{@year}_#{@establishment.id}.json",
              type:     "application/json"
  end

  def submit
    unless @establishment.persisted? && @entry.persisted?
      return redirect_to(osha_300a_path(year: @year), alert: "Establishment and workforce must be saved first.")
    end

    payload = Osha300aPayloadBuilder.new(
      establishment: @establishment,
      entry:         @entry,
      totals:        Osha300aTotals.for(@year)
    ).to_h

    @entry.update!(
      submitted_at:        Time.current,
      submitted_by_id:     session.dig(:user, "employee_id").to_s,
      submitted_payload:   payload,
      submission_response: { manual: true, note: "Marked as submitted; no ITA API call yet." }
    )

    redirect_to osha_300a_path(year: @year),
                notice: "Marked as submitted on #{@entry.submitted_at.strftime('%B %d, %Y at %I:%M %p')}."
  end

  private

  def set_year_and_records
    @year = (params[:year].presence || Date.current.year).to_i
    @establishment = OshaEstablishment.first || OshaEstablishment.new
    @entry = if @establishment.persisted?
               Osha300aEntry.find_or_initialize_by(osha_establishment: @establishment, year: @year)
             else
               Osha300aEntry.new(year: @year)
             end
  end

  def establishment_params
    params.require(:osha_establishment).permit(
      :name, :ein, :company_name, :street_address, :city, :state, :zip,
      :naics_code, :industry_description, :size, :establishment_type
    )
  end

  def entry_params
    params.require(:osha_300a_entry).permit(
      :annual_average_employees, :total_hours_worked, :change_reason
    )
  end

  def require_osha_log_access
    return if current_user_group_names.include?('system_admins')
    return if current_user_dropdown_permissions.include?('osha_log')
    redirect_to root_path, alert: "Access denied."
  end
end
